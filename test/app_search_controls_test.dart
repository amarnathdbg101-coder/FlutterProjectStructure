import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/core/widgets/app_ui_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'AppSearchField keeps search, clear and voice controls usable on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TextEditingController(text: 'rice');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AppSearchField(
                controller: controller,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppSearchField)).height, 52);
      expect(
        tester.getSize(find.byTooltip('Clear search')),
        const Size(44, 44),
      );
      expect(
        tester.getSize(find.byTooltip('Voice Search / Dictation')),
        const Size(44, 44),
      );
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    },
  );

  testWidgets('AppProductSearchBar matches the shared search and voice layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AppProductSearchBar(
              controller: controller,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppProductSearchBar)).height, 52);
    expect(
      tester.getSize(find.byTooltip('Voice Search / Dictation')),
      const Size(44, 44),
    );
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
  });
}
