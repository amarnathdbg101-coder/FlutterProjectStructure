import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/core/widgets/reusable/app_reusable.dart';

void main() {
  group('ShopSilo Reusable Widgets Tests', () {
    testWidgets('AppButton renders with primary variant, size and responds to tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Complete Sale',
              icon: Icons.check_circle_outline_rounded,
              onPressed: () => tapped = true,
              size: AppButtonSize.lg,
              isFullWidth: true,
            ),
          ),
        ),
      );

      expect(find.text('Complete Sale'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      await tester.tap(find.text('Complete Sale'));
      expect(tapped, isTrue);
    });

    testWidgets('AppButton shows spinner and disables tap when isLoading is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Saving Data',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Saving Data'));
      expect(tapped, isFalse);
    });

    testWidgets('AppButton.whatsapp renders with custom WhatsApp styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.whatsapp(
              text: 'Share Bill on WhatsApp',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Share Bill on WhatsApp'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('AppIconButton renders icon, badge and responds to tap', (tester) async {
      bool iconTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.shopping_cart_outlined,
              badgeCount: 3,
              tooltip: 'View Cart',
              onPressed: () => iconTapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      expect(iconTapped, isTrue);
    });

    testWidgets('AppFilterChip renders selected and unselected states correctly', (tester) async {
      bool chipSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppFilterChip(
                  label: 'Frequent Items',
                  count: 12,
                  isSelected: chipSelected,
                  onSelected: () => setState(() => chipSelected = !chipSelected),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Frequent Items'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      await tester.tap(find.text('Frequent Items'));
      await tester.pumpAndSettle();
      expect(chipSelected, isTrue);
    });

    testWidgets('AppTextInput renders label, hint and accepts text input', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextInput(
              controller: controller,
              label: 'Customer Mobile',
              hint: 'Enter 10-digit number',
              prefixText: '+91',
              isRequired: true,
            ),
          ),
        ),
      );

      expect(find.text('Customer Mobile'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
      expect(find.text('+91 '), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '9876543210');
      expect(controller.text, equals('9876543210'));
    });
  });
}

