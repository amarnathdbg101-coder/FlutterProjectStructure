import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/core/widgets/app_ui_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Industrial AppPdfShareModal Native Sharing & Printing Tests', () {
    testWidgets('AppPdfShareModal renders with document info, native share and print cards', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final langCtrl = LanguageController();

      Future<Uint8List> mockGetPdfBytes() async {
        return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageController>.value(value: langCtrl),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    AppPdfShareModal.show(
                      ctx,
                      title: 'Mandi Procurement Sheet',
                      subtitle: 'ShopSilo Partner Store • 5 items',
                      filename: 'Mandi_List.pdf',
                      getPdfBytes: mockGetPdfBytes,
                      customerPhone: '9876543210',
                      customerName: 'Ramesh Trader',
                    );
                  },
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // 1. Verify Header info
      expect(find.text('Mandi Procurement Sheet'), findsOneWidget);
      expect(find.text('ShopSilo Partner Store • 5 items'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);

      // 2. Verify Native Share Card (Bluetooth, WhatsApp, Instagram, etc.)
      expect(find.text('Share PDF Document'), findsOneWidget);
      expect(find.textContaining('Bluetooth, WhatsApp, Instagram'), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);

      // 3. Verify Print Card
      expect(find.text('Print Document'), findsOneWidget);
      expect(find.textContaining('Thermal or standard A4 printer'), findsOneWidget);
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);
    });
  });
}
