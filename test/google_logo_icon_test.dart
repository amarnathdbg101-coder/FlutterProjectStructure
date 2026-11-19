import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/core/widgets/google_logo_icon.dart';

void main() {
  testWidgets('GoogleLogoIcon renders vector canvas cleanly without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: GoogleLogoIcon(size: 24),
          ),
        ),
      ),
    );

    expect(find.byType(GoogleLogoIcon), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
