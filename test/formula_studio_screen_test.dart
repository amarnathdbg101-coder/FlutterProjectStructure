import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/ai_tutor/screens/formula_studio_screen.dart';

void main() {
  testWidgets('FormulaStudioScreen renders, filters, and navigates without crashing or blank screens', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormulaStudioScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Top Header
    expect(find.text('Formula Studio'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    // Verify initial card is rendered
    expect(find.text('Fundamental Theorem of Calculus'), findsOneWidget);

    // Test Subject Filter Chips
    final physicsChip = find.widgetWithText(FilterChip, 'Physics');
    expect(physicsChip, findsOneWidget);
    await tester.tap(physicsChip);
    await tester.pumpAndSettle();

    // Verify physics card is shown
    expect(find.text('Newton Second Law for Variable Mass (Rocket Equation)'), findsOneWidget);

    // Test Search Field
    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'Bernoulli');
    await tester.pumpAndSettle();
    expect(find.text('Bernoulli Conservation of Fluid Energy'), findsOneWidget);

    // Clear search
    final clearBtn = find.byIcon(Icons.clear);
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    // Test Switch to List View
    final switchModeBtn = find.byTooltip('Switch to Sheet / List View');
    expect(switchModeBtn, findsOneWidget);
    await tester.tap(switchModeBtn);
    await tester.pumpAndSettle();

    // Verify List view rendered
    expect(find.byType(ListView), findsWidgets);

    // Test Active Recall Mode Toggle
    final selfTestBtn = find.byTooltip('Enable Active Recall Self-Test Mode');
    expect(selfTestBtn, findsOneWidget);
    await tester.tap(selfTestBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('Active Recall Mode'), findsOneWidget);
  });
}
