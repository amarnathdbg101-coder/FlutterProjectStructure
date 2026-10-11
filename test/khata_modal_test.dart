import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/khata/controllers/khata_controller.dart';
import 'package:flutter_project_structure/features/khata/screens/khata_screen.dart';

void main() {
  testWidgets('Tapping Record Entry opens add transaction modal without crashing', (tester) async {
    final languageCtrl = LanguageController();
    final khataCtrl = KhataController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageController>.value(value: languageCtrl),
          ChangeNotifierProvider<KhataController>.value(value: khataCtrl),
        ],
        child: const MaterialApp(
          home: KhataScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find FloatingActionButton with Record Entry
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    // Tap it
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Verify modal is open and shows form fields
    expect(find.byType(TextField), findsWidgets);
  });
}
