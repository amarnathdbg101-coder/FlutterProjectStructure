import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/core/utils/latex_sanitizer.dart';

void main() {
  group('LatexSanitizer Universal Tests', () {
    test('Universally strips backslashes from arbitrary words like \\cent and \\example', () {
      expect(LatexSanitizer.clean(r'For \example: 50 \cent'), 'For example: 50 cent');
      expect(LatexSanitizer.clean(r'The \center of gravity is at \frac{L}{2}'), 'The center of gravity is at (L / 2)');
      expect(LatexSanitizer.clean(r'\step 1: Calculate \Delta x \approx 0'), 'step 1: Calculate Δ x ≈ 0');
    });

    test('Converts known Greek symbols and operators to clean Unicode', () {
      expect(LatexSanitizer.clean(r'\alpha + \beta = \gamma'), 'α + β = γ');
      expect(LatexSanitizer.clean(r'\tau = r \times F'), 'τ = r × F');
      expect(LatexSanitizer.clean(r'\lambda \le \mu'), 'λ ≤ μ');
      expect(LatexSanitizer.clean(r'\infty \pm 1'), '∞ ± 1');
    });

    test('Recursively unwraps arbitrary macros with braces', () {
      expect(LatexSanitizer.clean(r'\text{Hello World}'), 'Hello World');
      expect(LatexSanitizer.clean(r'\textbf{\textit{Deep Concept}}'), 'Deep Concept');
      expect(LatexSanitizer.clean(r'\customTag{Important Fact}'), 'Important Fact');
      expect(LatexSanitizer.clean(r'\example{Sorting logic}'), 'Sorting logic');
    });

    test('Handles mathematical functions without backslashes', () {
      expect(LatexSanitizer.clean(r'\log(x) + \sin(\theta)'), 'log(x) + sin(θ)');
      expect(LatexSanitizer.clean(r'O(N \log N)'), 'O(N log N)');
    });

    test('Un-escapes LaTeX escaped punctuation', () {
      expect(LatexSanitizer.clean(r'100\% guarantee on \$50'), r'100% guarantee on $50');
      expect(LatexSanitizer.clean(r'variable\_name \& count'), 'variable_name & count');
    });

    test('Handles superscripts and subscripts', () {
      expect(LatexSanitizer.clean(r'x^2 + y_1'), 'x² + y₁');
      expect(LatexSanitizer.clean(r'E = mc^2'), 'E = mc²');
    });
  });
}
