import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/main.dart';
import 'package:studysilo/features/ai_tutor/widgets/formatted_ai_text.dart';
import 'package:studysilo/features/diagram_viewer/widgets/interactive_visual_diagram.dart';

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

  testWidgets('interactive diagrams render visual diagram directly', (WidgetTester tester) async {
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

    expect(find.byType(InteractiveVisualDiagram), findsOneWidget);
  });

  testWidgets('inline LaTeX renders inside highlighted headings and bold text', (WidgetTester tester) async {
    const answer = r'''
### **$\rightarrow$ $q_0$ (Start)**

**$\rightarrow$ $q_1$ (Final)**
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

    final renderedText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.textSpan?.toPlainText() ?? widget.data ?? '')
        .join('\n');

    expect(renderedText, contains('→ q₀ (Start)'));
    expect(renderedText, contains('→ q₁ (Final)'));
    expect(renderedText, isNot(contains(r'\rightarrow')));
  });
}
