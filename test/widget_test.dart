import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/main.dart';
import 'package:flutter_project_structure/features/ai_tutor/widgets/formatted_ai_text.dart';
import 'package:flutter_project_structure/features/diagram_viewer/widgets/interactive_visual_diagram.dart';

void main() {
  testWidgets('App smoke test - verifies MaterialApp initializes', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });

  testWidgets('long AI answers render additional sections on demand', (WidgetTester tester) async {
    final answer = List.generate(30, (index) => 'Answer section $index').join('\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormattedAiText(text: answer, isDark: false),
          ),
        ),
      ),
    );

    expect(find.text('Load more (18 sections left)'), findsOneWidget);
    expect(find.text('Load more (6 sections left)'), findsNothing);

    await tester.tap(find.text('Load more (18 sections left)'));
    await tester.pumpAndSettle();

    expect(find.text('Load more (6 sections left)'), findsOneWidget);
  });

  testWidgets('interactive diagrams are deferred until requested', (WidgetTester tester) async {
    const answer = '''
```json
{"title":"Example","nodes":[{"id":"1","label":"Start"}],"edges":[]}
```
''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormattedAiText(text: answer, isDark: false),
          ),
        ),
      ),
    );

    expect(find.text('Render interactive diagram'), findsOneWidget);
    expect(find.byType(InteractiveVisualDiagram), findsNothing);
  });
}
