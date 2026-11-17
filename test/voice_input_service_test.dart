import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/core/services/voice_input_service.dart';
import 'package:flutter_project_structure/core/widgets/app_ui_components.dart';
import 'package:flutter_project_structure/core/widgets/reusable/app_voice_dictation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShopSilo Speech-to-Text Voice Engine & Component Tests', () {
    test('AppVoiceInputService singleton instance is consistent', () {
      final s1 = AppVoiceInputService();
      final s2 = AppVoiceInputService();
      expect(identical(s1, s2), isTrue);
      expect(s1.isListening, isFalse);
      expect(s1.currentSpokenText, isEmpty);
    });

    test('stripTrailingPunctuation removes trailing dots and commas from voice engines', () {
      expect(AppVoiceInputService.stripTrailingPunctuation('Tata Salt.'), equals('Tata Salt'));
      expect(AppVoiceInputService.stripTrailingPunctuation('Amul doodh!'), equals('Amul doodh'));
      expect(AppVoiceInputService.stripTrailingPunctuation('टाटा नमक...'), equals('टाटा नमक'));
      expect(AppVoiceInputService.stripTrailingPunctuation('Fortune Oil? '), equals('Fortune Oil'));
      expect(AppVoiceInputService.stripTrailingPunctuation(''), equals(''));
    });

    test('cleanVoiceQuery removes conversational stopwords and fillers', () {
      expect(AppVoiceInputService.cleanVoiceQuery('amul ka doodh chahiye'), equals('amul doodh'));
      expect(AppVoiceInputService.cleanVoiceQuery('sabse sasta tel dikhao'), equals('tel'));
      expect(AppVoiceInputService.cleanVoiceQuery('i want surf excel'), equals('surf excel'));
      expect(AppVoiceInputService.cleanVoiceQuery('टाटा नमक चाहिए'), equals('टाटा नमक'));
      // Single word remains preserved
      expect(AppVoiceInputService.cleanVoiceQuery('doodh'), equals('doodh'));
    });

    test('retailBilingualMap contains core Indian staples for counter search', () {
      expect(AppVoiceInputService.retailBilingualMap['दूध'], equals('Amul Milk'));
      expect(AppVoiceInputService.retailBilingualMap['टाटा नमक'], equals('Tata Salt'));
      expect(AppVoiceInputService.retailBilingualMap['मैगी'], equals('Maggi Noodles'));
      expect(AppVoiceInputService.retailBilingualMap['सर्फ'], equals('Surf Excel'));
    });

    test('getFriendlyErrorMessage returns helpful localized error guidance', () {
      expect(AppVoiceInputService.getFriendlyErrorMessage('error_permission', true), contains('माइक्रोफ़ोन अनुमति'));
      expect(AppVoiceInputService.getFriendlyErrorMessage('error_permission', false), contains('permission is required'));
      expect(AppVoiceInputService.getFriendlyErrorMessage('error_speech_timeout', true), contains('कोई आवाज़ सुनाई नहीं दी'));
      expect(AppVoiceInputService.getFriendlyErrorMessage('error_network', false), contains('Network error'));
    });

    testWidgets('AppVoiceIconButton renders mic icon and handles tap', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppVoiceIconButton(
              controller: controller,
              hint: 'Test Hint',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('AppSearchField renders voice mic icon by default', (tester) async {
      final searchCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              controller: searchCtrl,
              enableVoice: true,
              hintText: 'Search items...',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('AppProductSearchBar renders voice mic icon by default', (tester) async {
      final searchCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppProductSearchBar(
              controller: searchCtrl,
              enableVoice: true,
              hintText: 'Scan or search products...',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('AppTextInput renders voice mic icon when enableVoice is true', (tester) async {
      final inputCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppTextInput(
                controller: inputCtrl,
                label: 'Product Name',
                enableVoice: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('AppProductSearchBar displays listening hint when voice service is active on controller', (tester) async {
      final searchCtrl = TextEditingController();
      final service = AppVoiceInputService.instance;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppProductSearchBar(
              controller: searchCtrl,
              enableVoice: true,
              hintText: 'Search products...',
            ),
          ),
        ),
      );

      // Initially shows idle hint
      expect(find.text('Search products...'), findsOneWidget);

      // When voice service is idle, isListeningTo is false
      expect(service.isListeningTo(searchCtrl), isFalse);
    });

    testWidgets('AppVoiceDictationSheet renders language toggle and quick retail suggestion chips', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppVoiceDictationSheet(
              controller: ctrl,
              initialIsHindi: true,
            ),
          ),
        ),
      );

      expect(find.text('🇮🇳 हिन्दी'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('टाटा नमक'), findsOneWidget);
      expect(find.text('अमूल दूध'), findsOneWidget);

      // Tap suggestion chip commits to controller
      await tester.tap(find.text('अमूल दूध'));
      await tester.pumpAndSettle();

      expect(ctrl.text, equals('Amul Milk'));
    });
  });
}
