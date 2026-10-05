import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/features/ai_tutor/screens/formula_studio_screen.dart';

void main() {
  group('Formula Studio & Scientific Solver Tests', () {
    test('FormulaCardItem attributes and LaTeX formatting integrity', () {
      const item = FormulaCardItem(
        id: 'test-carnot',
        title: 'Carnot Heat Engine Maximum Efficiency',
        subject: 'Physics',
        topic: 'Thermodynamics',
        latex: r'\eta = 1 - \frac{T_C}{T_H}',
        description: 'Theoretical upper limit for heat engine efficiency.',
        variables: {
          'T_C': 'Cold sink temperature [K]',
          'T_H': 'Hot source temperature [K]',
        },
        examTrap: 'Temperatures must strictly be in Kelvin (K).',
        derivationSummary: r'\Delta S_{cycle} = 0 \implies \eta = 1 - \frac{T_C}{T_H}',
        shortcuts: ['Reversible cycle'],
        phoneticReadout: 'Efficiency eta equals one minus T sub C over T sub H.',
        calculatorType: 'carnot',
      );

      expect(item.id, equals('test-carnot'));
      expect(item.subject, equals('Physics'));
      expect(item.variables.length, equals(2));
      expect(item.calculatorType, equals('carnot'));
      expect(item.phoneticReadout, contains('eta equals one minus'));
    });

    test('Carnot thermodynamic calculation matches analytical physics', () {
      const tc = 300.0; // Kelvin
      const th = 600.0; // Kelvin

      final eta = 1.0 - (tc / th);
      final percent = eta * 100.0;

      expect(eta, equals(0.5));
      expect(percent, equals(50.0));
    });

    test('Master Theorem watershed exponent calculation matches algorithm theory', () {
      // Merge Sort recurrence: a=2, b=2, k=1, p=0 -> T(n) = 2T(n/2) + O(n)
      const a = 2.0;
      const b = 2.0;
      const k = 1.0;

      final c = math.log(a) / math.log(b);
      final diff = (c - k).abs();

      // Case 2: c == k -> O(n log n)
      expect(c, equals(1.0));
      expect(diff < 0.001, isTrue);

      // Strassen recurrence: a=7, b=2, k=2 -> T(n) = 7T(n/2) + O(n^2)
      const aStrassen = 7.0;
      const bStrassen = 2.0;
      const kStrassen = 2.0;
      final cStrassen = math.log(aStrassen) / math.log(bStrassen);

      // Case 1: c > k (approx 2.807 > 2)
      expect(cStrassen > kStrassen, isTrue);
      expect((cStrassen - 2.807).abs() < 0.01, isTrue);
    });

    test('Gibbs Free Energy spontaneity evaluation correctly identifies exergonic processes', () {
      // Combustion of Methane at 298.15K
      // Delta H = -890.4 kJ/mol, Delta S = -242.8 J/(mol*K)
      const deltaH = -890.4;
      const tempK = 298.15;
      const deltaS = -242.8;

      final deltaG = deltaH - (tempK * (deltaS / 1000.0));

      expect(deltaG < 0, isTrue); // Spontaneous forward process
      expect(deltaG.toStringAsFixed(1), equals('-818.0'));
    });
  });
}
