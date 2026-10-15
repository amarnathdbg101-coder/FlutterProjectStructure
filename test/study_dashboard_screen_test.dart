import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:flutter_project_structure/features/auth/controllers/auth_controller.dart';
import 'package:flutter_project_structure/core/theme/theme_controller.dart';
import 'package:flutter_project_structure/features/dashboard/presentation/screens/study_dashboard_screen.dart';
import 'package:flutter_project_structure/features/dashboard/presentation/widgets/omni_search_bar.dart';
import 'package:flutter_project_structure/features/dashboard/presentation/widgets/active_sprint_card.dart';
import 'package:flutter_project_structure/features/dashboard/presentation/widgets/study_engine_card.dart';

void main() {
  testWidgets('StudyDashboardScreen renders clean UI without overflow or errors', (tester) async {
    // Provide adequate mobile screen size
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
            ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
          ],
          child: const MaterialApp(
            home: StudyDashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Brand title & Header
    expect(find.text('StudySilo'), findsOneWidget);
    expect(find.text('Academic Workspace'), findsOneWidget);
    expect(find.text('Ready to learn today?'), findsOneWidget);

    // Verify Omni Search Bar is rendered
    expect(find.byType(OmniSearchBar), findsOneWidget);

    // Verify Active Sprint Hero Card
    expect(find.byType(ActiveSprintCard), findsOneWidget);

    // Verify AI Study Engines grid
    expect(find.text('AI STUDY ENGINES'), findsOneWidget);
    expect(find.byType(StudyEngineCard), findsWidgets);
  });
}
