import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/quiz/models/quiz_model.dart';
import 'package:studysilo/features/quiz/widgets/quiz_card.dart';
import 'package:studysilo/features/quiz/widgets/quiz_attempt_card.dart';

void main() {
  testWidgets('QuizCard and QuizAttemptCard render without pixel overflow on small phone', (tester) async {
    // Exact Vivo V2338 logical dimensions: 392.7 x 875.6 dp
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);

    final mockQuiz = QuizModel(
      id: 'quiz-1',
      userId: 'user-1',
      title: 'Branch Prediction & Advanced Pipeline Hazards in Superscalar Microarchitectures',
      topic: 'Computer Organization & Architecture (MIPS / RISC-V)',
      difficulty: 'adaptive',
      totalQuestions: 15,
      questions: const [],
      createdAt: DateTime.now(),
    );

    final mockAttempt = QuizAttemptModel(
      id: 'att-1',
      quizId: 'quiz-1',
      userId: 'user-1',
      score: 12,
      totalScore: 15,
      percentage: 80.0,
      timeTakenSeconds: 345,
      weakAreasIdentified: const ['Branch Hazard Delay Slots', 'Data Forwarding Paths'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // Simulate 1.15x font scaling as observed on the user's phone
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.15),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  QuizCard(
                    quiz: mockQuiz,
                    isDark: false,
                    onStart: () {},
                    onDelete: () {},
                  ),
                  const SizedBox(height: 16),
                  QuizAttemptCard(
                    attempt: mockAttempt,
                    isDark: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify elements render properly
    expect(find.textContaining('Branch Prediction'), findsOneWidget);
    expect(find.text('Start Quiz'), findsOneWidget);
    expect(find.textContaining('80.0%'), findsOneWidget);
    expect(find.textContaining('Score: 12 / 15'), findsOneWidget);
  });
}
