import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysilo/core/services/ai_language_service.dart';
import 'package:studysilo/core/theme/theme_controller.dart';
import 'package:studysilo/features/ai_tutor/controllers/ai_tutor_controller.dart';
import 'package:studysilo/features/auth/controllers/auth_controller.dart';
import 'package:studysilo/features/dashboard/presentation/screens/study_dashboard_screen.dart';
import 'package:studysilo/features/dashboard/presentation/widgets/study_engine_card.dart';
import 'package:studysilo/features/diagram_viewer/controllers/diagram_controller.dart';
import 'package:studysilo/features/health/controllers/health_controller.dart';
import 'package:studysilo/features/quiz/controllers/quiz_controller.dart';
import 'package:studysilo/features/quiz/models/quiz_model.dart';
import 'package:studysilo/features/quiz/widgets/quiz_attempt_card.dart';
import 'package:studysilo/features/quiz/widgets/quiz_card.dart';
import 'package:studysilo/features/student_memory/controllers/cognitive_profile_controller.dart';
import 'package:studysilo/features/student_memory/models/flashcard_model.dart';
import 'package:studysilo/features/student_memory/widgets/flip_flashcard_widget.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AILanguageService.init();
  });

  Widget wrapWithTheme(Widget child, {double width = 360, double height = 800, double textScale = 1.0}) {
    return ProviderScope(
      child: legacy_provider.MultiProvider(
        providers: [
          legacy_provider.ChangeNotifierProvider(create: (_) => ThemeController()),
          legacy_provider.ChangeNotifierProvider(create: (_) => AuthController()),
          legacy_provider.ChangeNotifierProvider(create: (_) => HealthController()),
          legacy_provider.ChangeNotifierProvider(create: (_) => AiTutorController()),
          legacy_provider.ChangeNotifierProvider(create: (_) => DiagramController()),
          legacy_provider.ChangeNotifierProvider(create: (_) => QuizController()),
          legacy_provider.ChangeNotifierProvider(create: (_) => CognitiveProfileController()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  testWidgets('StudyEngineCard renders with 0 overflow on narrow 320dp and 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(320 * 2.0, 600 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrapWithTheme(
        SizedBox(
          width: 145,
          height: 120,
          child: StudyEngineCard(
            title: 'Hierarchical Concept Maps',
            description: 'Multi-branching dynamic mind map canvas with automated layout',
            icon: Icons.hub_rounded,
            onTap: () {},
          ),
        ),
        width: 320,
        textScale: 1.3,
      ),
    );

    expect(find.text('Hierarchical Concept Maps'), findsOneWidget);
  });

  testWidgets('QuizCard & QuizAttemptCard render with 0 overflow across font scales', (tester) async {
    tester.view.physicalSize = const Size(360 * 2.5, 780 * 2.5);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    final mockQuiz = QuizModel(
      id: 'quiz-overflow-check',
      userId: 'user-1',
      title: 'Advanced Microarchitecture: Speculative Execution, Branch Predictors & Pipeline Hazards',
      topic: 'Computer Organization & Architecture (RISC-V)',
      difficulty: 'adaptive',
      totalQuestions: 20,
      questions: const [],
      createdAt: DateTime.now(),
    );

    final mockAttempt = QuizAttemptModel(
      id: 'att-overflow-check',
      quizId: 'quiz-overflow-check',
      userId: 'user-1',
      score: 18,
      totalScore: 20,
      percentage: 90.0,
      timeTakenSeconds: 450,
      weakAreasIdentified: const ['Branch Predictor Saturation Counter', 'Data Forwarding Hazards'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      wrapWithTheme(
        SingleChildScrollView(
          child: Column(
            children: [
              QuizCard(quiz: mockQuiz, isDark: false, onStart: () {}, onDelete: () {}),
              const SizedBox(height: 12),
              QuizAttemptCard(attempt: mockAttempt, isDark: false),
            ],
          ),
        ),
        width: 360,
        textScale: 1.25,
      ),
    );

    expect(find.byType(QuizCard), findsOneWidget);
    expect(find.byType(QuizAttemptCard), findsOneWidget);
  });

  testWidgets('FlipFlashcardWidget renders with 0 overflow on narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 2.0, 600 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final card = FlashcardModel(
      id: 'fc-1',
      topic: 'Operating Systems',
      questionFront: 'What are the 4 Coffman conditions required for Deadlock occurrence?',
      answerBack: 'Mutual Exclusion, Hold and Wait, No Preemption, Circular Wait.',
      difficulty: 'medium',
      isMastered: false,
      isReviewed: true,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      wrapWithTheme(
        FlipFlashcardWidget(flashcard: card, isDark: false),
        width: 320,
        textScale: 1.2,
      ),
    );

    expect(find.text(card.questionFront), findsOneWidget);
  });

  testWidgets('StudyDashboardScreen renders with 0 overflow on 360dp phone with 1.2x font scale', (tester) async {
    tester.view.physicalSize = const Size(360 * 3.0, 800 * 3.0);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrapWithTheme(
        const StudyDashboardScreen(),
        width: 360,
        textScale: 1.2,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('StudySilo'), findsOneWidget);
  });
}
