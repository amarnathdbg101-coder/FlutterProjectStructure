import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:studysilo/features/quiz/controllers/quiz_controller.dart';
import 'package:studysilo/features/quiz/models/quiz_model.dart';
import 'package:studysilo/features/quiz/repositories/quiz_repository.dart';
import 'package:studysilo/features/quiz/screens/quiz_taker_screen.dart';

class MockQuizRepository extends QuizRepository {
  @override
  Future<CognitiveProfileModel> getCognitiveProfile() async {
    return CognitiveProfileModel();
  }

  @override
  Future<List<QuizAttemptModel>> getQuizAttempts({String? quizId}) async {
    return [];
  }

  @override
  Future<QuizSubmissionResponseModel> submitQuiz({
    required String quizId,
    required List<Map<String, dynamic>> answers,
    int timeTakenSeconds = 0,
  }) async {
    return QuizSubmissionResponseModel(
      attemptId: 'att-123',
      quizId: quizId,
      score: 1,
      totalScore: 2,
      percentage: 50.0,
      feedback: [
        QuestionFeedbackModel(
          questionId: 'q-1',
          questionType: 'mcq',
          questionText: 'What is the time complexity of binary search?',
          options: const ['O(1)', 'O(log n)', 'O(n)', 'O(n^2)'],
          selectedOption: 1,
          correctOptionIndex: 1,
          score: 1,
          maxMarks: 1,
          isCorrect: true,
          explanation: 'Binary search divides the search space in half at each step, yielding O(log n).',
        ),
        QuestionFeedbackModel(
          questionId: 'q-2',
          questionType: 'mcq',
          questionText: 'What is an idempotent HTTP method?',
          options: const ['POST', 'GET', 'PATCH', 'CONNECT'],
          selectedOption: -1, // Skipped by student
          correctOptionIndex: 1,
          score: 0,
          maxMarks: 1,
          isCorrect: false,
          explanation: 'GET is idempotent because repeated identical requests produce the same side effect.',
        ),
      ],
      weakAreasIdentified: const ['REST API Semantics'],
      studyStreakDays: 5,
      totalQuizzesTaken: 10,
      averageQuizScore: 78.5,
    );
  }
}

void main() {
  testWidgets('QuizTakerScreen: Navigation, Early Submission Dialog, and Professional Results', (tester) async {
    final mockRepo = MockQuizRepository();
    final controller = QuizController(repository: mockRepo);

    final testQuiz = QuizModel(
      id: 'quiz-nav-test',
      userId: 'user-1',
      title: 'Full Stack Engineering Exam',
      topic: 'Data Structures & Web APIs',
      difficulty: 'medium',
      totalQuestions: 2,
      createdAt: DateTime.now(),
      questions: [
        QuizQuestionModel(
          id: 'q-1',
          quizId: 'quiz-nav-test',
          questionText: 'What is the time complexity of binary search?',
          options: const ['O(1)', 'O(log n)', 'O(n)', 'O(n^2)'],
          correctOptionIndex: 1,
          explanation: 'Binary search divides search space in half.',
          maxMarks: 1,
          difficulty: 'medium',
          topic: 'Algorithms',
        ),
        QuizQuestionModel(
          id: 'q-2',
          quizId: 'quiz-nav-test',
          questionText: 'What is an idempotent HTTP method?',
          options: const ['POST', 'GET', 'PATCH', 'CONNECT'],
          correctOptionIndex: 1,
          explanation: 'GET is idempotent.',
          maxMarks: 1,
          difficulty: 'medium',
          topic: 'Web APIs',
        ),
      ],
    );

    await controller.startQuiz(testQuiz);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<QuizController>.value(
          value: controller,
          child: const QuizTakerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Q1 is displayed
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(find.textContaining('binary search'), findsOneWidget);
    expect(find.text('Next Question'), findsOneWidget);

    // 2. Select option B for Q1
    await tester.tap(find.text('O(log n)'));
    await tester.pumpAndSettle();

    // 3. Tap 'Next Question' button
    await tester.tap(find.text('Next Question'));
    await tester.pumpAndSettle();

    // 4. Verify Q2 is displayed
    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(find.textContaining('idempotent HTTP method'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);

    // 5. Test Tap 'Previous' button to navigate back
    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 2'), findsOneWidget);

    // 6. Test Quick Question Palette: Tap '2' to jump to Q2
    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();
    expect(find.text('Question 2 of 2'), findsOneWidget);

    // 7. Early Submission Test: Tap top AppBar 'Submit' button
    await tester.tap(find.text('Submit').first);
    await tester.pumpAndSettle();

    // Verify Pre-Submission Confirmation Dialog appeared
    expect(find.text('Submit Examination?'), findsOneWidget);
    expect(find.text('Review Questions'), findsOneWidget);
    expect(find.text('Submit & Finish Exam'), findsOneWidget);
    expect(find.textContaining('1 / 2'), findsOneWidget); // 1 attempted

    // 8. Confirm Submission
    await tester.tap(find.text('Submit & Finish Exam'));
    await tester.pumpAndSettle();

    // 9. Verify Professional Results Screen
    expect(find.text('Exam Assessment & Results'), findsOneWidget);
    expect(find.textContaining('1 / 2 Marks'), findsOneWidget);
    expect(find.textContaining('50.0%'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);

    // Verify Solution Filter Chips
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Correct (1)'), findsOneWidget);
    expect(find.text('Unanswered (1)'), findsOneWidget);

    // Verify Re-attempt button is available
    expect(find.text('Re-attempt Test'), findsOneWidget);
  });
}
