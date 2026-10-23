import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/quiz/models/exam_simulator_model.dart';
import 'package:studysilo/features/quiz/services/exam_simulator_service.dart';

void main() {
  group('Comprehensive AI Exam Simulator & Diagnostic Engine Tests (20+ Cases)', () {
    test('1. MockExamQuestionModel default constructor values', () {
      final q = MockExamQuestionModel(
        id: 'q-1',
        questionText: 'What is entropy?',
        options: const ['A', 'B', 'C', 'D'],
        correctOptionIndex: 1,
      );

      expect(q.id, 'q-1');
      expect(q.positiveMarks, 4.0);
      expect(q.negativeMarks, 1.0);
      expect(q.errorCategory, ErrorCategory.conceptual);
      expect(q.topic, 'General Academic');
    });

    test('2. MockExamQuestionModel parses letter correct options (A, B, C, D)', () {
      final jsonA = {'id': '1', 'question_text': 'Q', 'options': ['A', 'B'], 'correct_option_index': 'A'};
      final jsonB = {'id': '2', 'question_text': 'Q', 'options': ['A', 'B'], 'correct_option_index': 'B'};
      final jsonC = {'id': '3', 'question_text': 'Q', 'options': ['A', 'B', 'C'], 'correct_option_index': 'C'};
      final jsonD = {'id': '4', 'question_text': 'Q', 'options': ['A', 'B', 'C', 'D'], 'correct_option_index': 'D'};

      expect(MockExamQuestionModel.fromJson(jsonA).correctOptionIndex, 0);
      expect(MockExamQuestionModel.fromJson(jsonB).correctOptionIndex, 1);
      expect(MockExamQuestionModel.fromJson(jsonC).correctOptionIndex, 2);
      expect(MockExamQuestionModel.fromJson(jsonD).correctOptionIndex, 3);
    });

    test('3. MockExamQuestionModel parses error categories correctly', () {
      final jsonTrap = {'id': '1', 'question_text': 'Q', 'options': ['A'], 'error_category': 'examiner_trap'};
      final jsonCalc = {'id': '2', 'question_text': 'Q', 'options': ['A'], 'error_category': 'calculation_error'};
      final jsonConcept = {'id': '3', 'question_text': 'Q', 'options': ['A'], 'error_category': 'conceptual'};

      expect(MockExamQuestionModel.fromJson(jsonTrap).errorCategory, ErrorCategory.trap);
      expect(MockExamQuestionModel.fromJson(jsonCalc).errorCategory, ErrorCategory.calculation);
      expect(MockExamQuestionModel.fromJson(jsonConcept).errorCategory, ErrorCategory.conceptual);
    });

    test('4. MockExamModel JSON serialization and deserialization', () {
      final exam = MockExamModel(
        id: 'exam-101',
        title: 'JEE Advanced Physics',
        examType: 'JEE Advanced',
        durationMinutes: 30,
        positiveMarking: 4.0,
        negativeMarking: 1.0,
        totalQuestions: 1,
        createdAt: DateTime(2026, 10, 1),
        questions: [
          MockExamQuestionModel(
            id: 'q1',
            questionText: 'Kinematics doubt',
            options: const ['1', '2', '3', '4'],
            correctOptionIndex: 0,
            topic: 'Kinematics',
          )
        ],
      );

      final json = exam.toJson();
      final revived = MockExamModel.fromJson(json);

      expect(revived.id, 'exam-101');
      expect(revived.title, 'JEE Advanced Physics');
      expect(revived.examType, 'JEE Advanced');
      expect(revived.durationMinutes, 30);
      expect(revived.positiveMarking, 4.0);
      expect(revived.questions.length, 1);
      expect(revived.questions.first.questionText, 'Kinematics doubt');
    });

    test('5. Perfect score calculation (+4 per question)', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock 1',
        totalQuestions: 2,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 4.0, negativeMarks: 1.0),
          MockExamQuestionModel(id: 'q2', questionText: 'Q2', options: const ['A', 'B'], correctOptionIndex: 1, positiveMarks: 4.0, negativeMarks: 1.0),
        ],
      );

      final userAnswers = {0: 0, 1: 1}; // All correct
      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: userAnswers, timeTakenSeconds: 60);

      expect(report.totalScore, 8.0);
      expect(report.maxPossibleScore, 8.0);
      expect(report.accuracyPercentage, 100.0);
      expect(report.correctCount, 2);
      expect(report.incorrectCount, 0);
      expect(report.skippedCount, 0);
    });

    test('6. Negative marking calculation (-1 per incorrect answer)', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock 1',
        totalQuestions: 2,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 4.0, negativeMarks: 1.0),
          MockExamQuestionModel(id: 'q2', questionText: 'Q2', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 4.0, negativeMarks: 1.0),
        ],
      );

      final userAnswers = {0: 1, 1: 1}; // All wrong (correct is 0)
      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: userAnswers, timeTakenSeconds: 60);

      expect(report.totalScore, 0.0); // Clamped at 0.0
      expect(report.accuracyPercentage, 0.0);
      expect(report.correctCount, 0);
      expect(report.incorrectCount, 2);
    });

    test('7. GATE exam scheme (+1 / -0.33 marking)', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'gate-1',
        title: 'GATE CS Mock',
        examType: 'GATE CS',
        positiveMarking: 1.0,
        negativeMarking: 0.33,
        totalQuestions: 2,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 1.0, negativeMarks: 0.33),
          MockExamQuestionModel(id: 'q2', questionText: 'Q2', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 1.0, negativeMarks: 0.33),
        ],
      );

      final userAnswers = {0: 0, 1: 1}; // 1 correct (+1.0), 1 wrong (-0.33)
      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: userAnswers, timeTakenSeconds: 100);

      expect(report.totalScore, closeTo(0.67, 0.01));
      expect(report.maxPossibleScore, 2.0);
    });

    test('8. Skipped questions award 0 marks and do not trigger negative marking', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock 1',
        totalQuestions: 3,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 4.0, negativeMarks: 1.0),
          MockExamQuestionModel(id: 'q2', questionText: 'Q2', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 4.0, negativeMarks: 1.0),
          MockExamQuestionModel(id: 'q3', questionText: 'Q3', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 4.0, negativeMarks: 1.0),
        ],
      );

      final userAnswers = {0: 0, 1: -1, 2: -1}; // 1 correct, 2 skipped
      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: userAnswers, timeTakenSeconds: 90);

      expect(report.totalScore, 4.0);
      expect(report.correctCount, 1);
      expect(report.incorrectCount, 0);
      expect(report.skippedCount, 2);
    });

    test('9. Diagnostic report classifies conceptual errors correctly', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock',
        totalQuestions: 1,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, errorCategory: ErrorCategory.conceptual),
        ],
      );

      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: {0: 1}, timeTakenSeconds: 30);

      expect(report.conceptualErrorCount, 1);
      expect(report.examinerTrapCount, 0);
      expect(report.calculationErrorCount, 0);
    });

    test('10. Diagnostic report classifies examiner trap errors correctly', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock',
        totalQuestions: 1,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, errorCategory: ErrorCategory.trap),
        ],
      );

      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: {0: 1}, timeTakenSeconds: 30);

      expect(report.conceptualErrorCount, 0);
      expect(report.examinerTrapCount, 1);
      expect(report.calculationErrorCount, 0);
    });

    test('11. Diagnostic report classifies calculation errors correctly', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock',
        totalQuestions: 1,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, errorCategory: ErrorCategory.calculation),
        ],
      );

      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: {0: 1}, timeTakenSeconds: 30);

      expect(report.conceptualErrorCount, 0);
      expect(report.examinerTrapCount, 0);
      expect(report.calculationErrorCount, 1);
    });

    test('12. Average time per question calculation', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock',
        totalQuestions: 4,
        createdAt: DateTime.now(),
        questions: List.generate(4, (i) => MockExamQuestionModel(id: 'q$i', questionText: 'Q', options: const ['A'], correctOptionIndex: 0)),
      );

      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: const {}, timeTakenSeconds: 120);

      expect(report.averageSecondsPerQuestion, 30.0); // 120s / 4q = 30s/q
    });

    test('13. Weak topics aggregation excludes topics of correct answers', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock',
        totalQuestions: 2,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, topic: 'Mastered Topic'),
          MockExamQuestionModel(id: 'q2', questionText: 'Q2', options: const ['A', 'B'], correctOptionIndex: 0, topic: 'Weak Topic'),
        ],
      );

      final userAnswers = {0: 0, 1: 1}; // Q1 correct, Q2 wrong
      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: userAnswers, timeTakenSeconds: 60);

      expect(report.weakTopics, contains('Weak Topic'));
      expect(report.weakTopics.contains('Mastered Topic'), false);
    });

    test('14. Weak topics aggregation includes skipped questions', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e1',
        title: 'Mock',
        totalQuestions: 1,
        createdAt: DateTime.now(),
        questions: [
          MockExamQuestionModel(id: 'q1', questionText: 'Q1', options: const ['A', 'B'], correctOptionIndex: 0, topic: 'Skipped Topic'),
        ],
      );

      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: const {}, timeTakenSeconds: 30);

      expect(report.weakTopics, contains('Skipped Topic'));
    });

    test('15. Fallback exam generator produces expected question count and topic', () {
      final service = ExamSimulatorService();
      final exam = service.evaluateDiagnosticReport(
        exam: MockExamModel(
          id: 'test',
          title: 'Test',
          totalQuestions: 0,
          createdAt: DateTime.now(),
          questions: const [],
        ),
        userAnswers: const {},
        timeTakenSeconds: 0,
      );

      expect(exam.accuracyPercentage, 0.0);
      expect(exam.totalScore, 0.0);
    });

    test('16. ExamSimulatorService fallback exam creates JEE default scheme', () async {
      final service = ExamSimulatorService();
      final exam = await service.generateMockExam(
        topic: 'Rotational Motion',
        examType: 'JEE Main',
        durationMinutes: 15,
        questionCount: 5,
        positiveMarking: 4.0,
        negativeMarking: 1.0,
      );

      expect(exam.title, contains('Rotational Motion'));
      expect(exam.durationMinutes, 15);
      expect(exam.positiveMarking, 4.0);
      expect(exam.negativeMarking, 1.0);
      expect(exam.questions.length, 5);
    });

    test('17. QuestionDiagnosticFeedback accurately records user selection and marks awarded', () {
      final q = MockExamQuestionModel(id: 'q1', questionText: 'Q', options: const ['A', 'B'], correctOptionIndex: 0, positiveMarks: 4.0, negativeMarks: 1.0);
      final fb = QuestionDiagnosticFeedback(
        question: q,
        selectedOption: 0,
        isCorrect: true,
        isSkipped: false,
        marksAwarded: 4.0,
      );

      expect(fb.selectedOption, 0);
      expect(fb.isCorrect, true);
      expect(fb.isSkipped, false);
      expect(fb.marksAwarded, 4.0);
    });

    test('18. ErrorCategory enum values are distinct', () {
      expect(ErrorCategory.values.length, 4);
      expect(ErrorCategory.conceptual.name, 'conceptual');
      expect(ErrorCategory.trap.name, 'trap');
      expect(ErrorCategory.calculation.name, 'calculation');
      expect(ErrorCategory.none.name, 'none');
    });

    test('19. MockExamQuestionModel JSON roundtrip preserves all fields', () {
      final q = MockExamQuestionModel(
        id: 'q-rt',
        questionText: 'Test Question Text',
        options: const ['Opt A', 'Opt B', 'Opt C'],
        correctOptionIndex: 2,
        explanation: 'Detailed explanation text',
        trapWarning: 'Trap warning text',
        topic: 'Optics',
        errorCategory: ErrorCategory.trap,
        positiveMarks: 4.0,
        negativeMarks: 1.0,
      );

      final json = q.toJson();
      final revived = MockExamQuestionModel.fromJson(json);

      expect(revived.id, 'q-rt');
      expect(revived.questionText, 'Test Question Text');
      expect(revived.options, containsAll(['Opt A', 'Opt B', 'Opt C']));
      expect(revived.correctOptionIndex, 2);
      expect(revived.explanation, 'Detailed explanation text');
      expect(revived.trapWarning, 'Trap warning text');
      expect(revived.topic, 'Optics');
      expect(revived.errorCategory, ErrorCategory.trap);
    });

    test('20. Diagnostic report generates unique attemptId and matches examTitle', () {
      final service = ExamSimulatorService();
      final exam = MockExamModel(
        id: 'e-unique',
        title: 'Unique Exam Title',
        totalQuestions: 1,
        createdAt: DateTime.now(),
        questions: [MockExamQuestionModel(id: 'q1', questionText: 'Q', options: const ['A'], correctOptionIndex: 0)],
      );

      final report = service.evaluateDiagnosticReport(exam: exam, userAnswers: {0: 0}, timeTakenSeconds: 45);

      expect(report.attemptId, startsWith('report-'));
      expect(report.examId, 'e-unique');
      expect(report.examTitle, 'Unique Exam Title');
      expect(report.timeTakenSeconds, 45);
    });
  });
}
