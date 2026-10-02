import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/main.dart';

void main() {
  testWidgets('App smoke test - verifies MaterialApp initializes', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
