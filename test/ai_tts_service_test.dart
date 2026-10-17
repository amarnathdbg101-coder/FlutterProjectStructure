import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/voice_doubt/services/ai_tts_service.dart';
import 'package:studysilo/features/voice_doubt/services/ai_audio_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AiTtsService Academic Spoken Sanitizer Tests', () {
    test('Transforms complex LaTeX fractions and square roots into natural speech', () {
      const input = r'The acceleration is given by a = \frac{v_2 - v_1}{\Delta t} and r = \sqrt{x^2 + y^2}';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('divided by'), isTrue);
      expect(spoken.contains('square root of'), isTrue);
      expect(spoken.contains('delta t'), isTrue);
      expect(spoken.contains('squared'), isTrue);
      expect(spoken.contains(r'\'), isFalse);
    });

    test('Translates calculus integrals, summations, and limits professionally', () {
      const input = r'Calculate \int_{0}^{1} x^2 dx and \sum_{i=1}^{n} i and \lim_{x \to 0} \frac{\sin x}{x}';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('definite integral from 0 to 1 of'), isTrue);
      expect(spoken.contains('summation from i=1 to n of'), isTrue);
      expect(spoken.contains('limit as x approaches 0 of'), isTrue);
      expect(spoken.contains('divided by'), isTrue);
      expect(spoken.contains(r'\'), isFalse);
    });

    test('Universally handles arbitrary LaTeX words like \\cent and \\example', () {
      const input = r'For \example, the ticket costs 50 \cent and the \center of gravity is at point G.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('For example,'), isTrue);
      expect(spoken.contains('50 cents'), isTrue);
      expect(spoken.contains('center of gravity'), isTrue);
      expect(spoken.contains(r'\'), isFalse);
    });

    test('Speaks algorithmic Big-O complexities naturally', () {
      const input = 'Merge Sort has time complexity O(N log N) and auxiliary space O(N). Hash Map lookup is O(1).';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('O of N log N linearithmic time'), isTrue);
      expect(spoken.contains('O of N linear time'), isTrue);
      expect(spoken.contains('O of 1 constant time'), isTrue);
    });

    test('Transforms chemical notations, vectors, and units', () {
      const input = r'Combustion produces CO_2 and H_2O. The force is \vec{F} = m \vec{a}.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('CO 2'), isTrue);
      expect(spoken.contains('H 2 O'), isTrue);
      expect(spoken.contains('vector F'), isTrue);
      expect(spoken.contains('vector a'), isTrue);
      expect(spoken.contains(r'\'), isFalse);
    });

    test('Transforms markdown tables and omits code syntax soup', () {
      const input = '''
Here is the summary:
| Method | Complexity | Stability |
|---|---|---|
| Merge Sort | O(N log N) | Stable |

```python
def merge_sort(arr):
    return sorted(arr)
```
''';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('Here is the code implementation.'), isTrue);
      expect(spoken.contains('def merge_sort'), isFalse);
      expect(spoken.contains('|'), isFalse);
    });

    test('Translates study emojis to polite professional human cues', () {
      const input = '💡 Remember this formula. ⚠️ Do not divide by zero. 🎯 Exam favorite topic.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('Pro tip:'), isTrue);
      expect(spoken.contains('Watch out, exam trap warning:'), isTrue);
      expect(spoken.contains('Key exam takeaway:'), isTrue);
    });

    test('Strict Zero Leakage: Never vocalizes dollar sign or backslash characters', () {
      const input = r'Einstein gave $E = mc^2$ and Newton gave $$\vec{F} = m \cdot \vec{a}$$. Here \alpha \le \beta.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      // Must never contain dollar character or backslash character
      expect(spoken.contains(r'$'), isFalse);
      expect(spoken.contains(r'\'), isFalse);
      // Must not pronounce the word 'dollar' for math delimiters
      expect(spoken.toLowerCase().contains('dollar'), isFalse);
      // Must pronounce mathematical terms cleanly
      expect(spoken.contains('E = mc squared'), isTrue);
      expect(spoken.contains('alpha is less than or equal to beta'), isTrue);
    });

    test('Speaks Physics SI Units and dimensions naturally', () {
      const input = r'Acceleration is 9.8 m/s^2, resistance is 50 \Omega, capacitance is 10 \mu F, and enthalpy is 100 kJ/mol at 25 °C.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('meters per second squared'), isTrue);
      expect(spoken.contains('50 ohms'), isTrue);
      expect(spoken.contains('10 microfarads'), isTrue);
      expect(spoken.contains('100 kilojoules per mole'), isTrue);
      expect(spoken.contains('25 degrees Celsius'), isTrue);
      expect(spoken.contains(r'\'), isFalse);
    });

    test('Speaks Chemistry physical states and reaction arrows naturally', () {
      const input = r'CaCO_3(s) \xrightarrow{\Delta} CaO(s) + CO_2(g) and N_2 + 3H_2 \rightleftharpoons 2NH_3';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('solid'), isTrue);
      expect(spoken.contains('reacts under heat to form'), isTrue);
      expect(spoken.contains('gas'), isTrue);
      expect(spoken.contains('is in dynamic reversible equilibrium with'), isTrue);
      expect(spoken.contains(r'\'), isFalse);
    });

    test('Expands academic abbreviations naturally with realistic teacher cadence', () {
      const input = 'For e.g., in fig. 1, eqn. 2 has approx. 50 kg w.r.t. the ground. soln. is verified.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('for example,'), isTrue);
      expect(spoken.contains('figure 1'), isTrue);
      expect(spoken.contains('equation 2'), isTrue);
      expect(spoken.contains('approximately 50 kilograms'), isTrue);
      expect(spoken.contains('with respect to the ground'), isTrue);
      expect(spoken.contains('solution is verified'), isTrue);
    });

    test('Speaks Physics subscript variables and common fractions cleanly', () {
      const input = r'Initial velocity is v_0, final is v_f, net force is F_net = 1/2 m v^2 at 50% efficiency.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('v naught'), isTrue);
      expect(spoken.contains('v final'), isTrue);
      expect(spoken.contains('F net'), isTrue);
      expect(spoken.contains('one half'), isTrue);
      expect(spoken.contains('50 percent'), isTrue);
    });

    test('Speaks CS array indexing, acronyms, and exponential complexity', () {
      const input = 'We access arr[i] and call the REST API. Time complexity is O(2^n) and space is O(n!).';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('array at index i'), isTrue);
      expect(spoken.contains('A P I'), isTrue);
      expect(spoken.contains('O of 2 to the power n exponential time'), isTrue);
      expect(spoken.contains('O of n factorial time'), isTrue);
    });

    test('Speaks common Chemistry formulas with accurate compound names', () {
      const input = 'Titration of HCl with NaOH produces NaCl and H2O.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('hydrochloric acid, H C L'), isTrue);
      expect(spoken.contains('sodium hydroxide, N A O H'), isTrue);
      expect(spoken.contains('sodium chloride, N A C L'), isTrue);
      expect(spoken.contains('water, H 2 O'), isTrue);
    });

    test('Speaks yellow-highlighted bold text accurately and NEVER says "one" or dollar', () {
      const input = 'The **acceleration** of an object is directly proportional to the **net force** and inversely to **total mass**.';
      final spoken = AiTtsService.sanitizeTextForSpeech(input);

      expect(spoken.contains('acceleration of an object is directly proportional to the net force'), isTrue);
      expect(spoken.contains('total mass'), isTrue);
      expect(spoken.contains('one'), isFalse);
      expect(spoken.contains('1'), isFalse);
      expect(spoken.contains(r'$'), isFalse);
    });
  });

  group('AiAudioCacheService & Dual-Engine Tests', () {
    test('Computes deterministic FNV-1a 64-bit hashes for audio caching', () {
      const text1 = 'Hello, Newton second law of motion is F = ma';
      const text2 = 'Hello, Newton second law of motion is F = ma';
      const text3 = 'Different text';

      final hash1 = AiAudioCacheService.computeHash(text1);
      final hash2 = AiAudioCacheService.computeHash(text2);
      final hash3 = AiAudioCacheService.computeHash(text3);

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
      expect(hash1.length, equals(16));
    });

    test('AiTtsService persona switching and rate cycling operate correctly', () {
      final service = AiTtsService();
      expect(service.persona, equals(VoicePersona.priya));

      service.setPersona(VoicePersona.aryan);
      expect(service.persona, equals(VoicePersona.aryan));

      service.setPersona(VoicePersona.mentor);
      expect(service.persona, equals(VoicePersona.mentor));

      // Test rate cycle
      service.cycleSpeechRate();
      expect(service.speechRate, equals(1.25));
      service.cycleSpeechRate();
      expect(service.speechRate, equals(1.5));
      service.cycleSpeechRate();
      expect(service.speechRate, equals(2.0));
      service.cycleSpeechRate();
      expect(service.speechRate, equals(1.0));
    });

    test('AiTtsService sleep timer and data saver mode operate correctly', () {
      final service = AiTtsService();
      expect(service.isDataSaverMode, isFalse);

      service.toggleDataSaverMode();
      expect(service.isDataSaverMode, isTrue);

      service.toggleDataSaverMode();
      expect(service.isDataSaverMode, isFalse);

      // Sleep timer tests
      expect(service.sleepTimerMinutes, isNull);
      service.setSleepTimer(15);
      expect(service.sleepTimerMinutes, equals(15));
      service.cancelSleepTimer();
      expect(service.sleepTimerMinutes, isNull);
    });

    test('AiAudioCacheService pruneOldCache runs safely without exceptions', () async {
      await AiAudioCacheService().pruneCacheIfNeeded(maxBytes: 10 * 1024 * 1024);
      AiAudioCacheService().clearMemoryCache();
    });
  });
}
