import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../repositories/ai_tutor_repository.dart';
import '../widgets/formatted_ai_text.dart';

/// Comprehensive model for an academic formula card
class FormulaCardItem {
  final String id;
  final String title;
  final String subject; // "Mathematics", "Physics", "Chemistry", "Computer Science"
  final String topic;
  final String latex;
  final String description;
  final Map<String, String> variables; // e.g. {"F": "Force [N]", "m": "Mass [kg]"}
  final String examTrap;
  final String derivationSummary;
  final List<String> shortcuts;
  final String phoneticReadout;
  final String calculatorType;

  const FormulaCardItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.topic,
    required this.latex,
    required this.description,
    this.variables = const {},
    this.examTrap = '',
    this.derivationSummary = '',
    this.shortcuts = const [],
    this.phoneticReadout = '',
    this.calculatorType = 'general',
  });
}

/// Standalone Full-Page AI Formula Studio & Equation Vault
/// Features:
/// 1. Full GoRouter navigation with working Back & Forward buttons
/// 2. Interactive Card Deck with prominent Next & Previous controls
/// 3. Instant Pre-loaded Academic Formula Vault (Zero loading lag)
/// 4. Fast Subject Filtering & Real-time Search
/// 5. SharedPreferences-backed Bookmarks / Favorites system
/// 6. Interactive Scientific Formula Solver & Dynamic Calculator
/// 7. Active Recall / Self-Test Flashcard Practice Mode
/// 8. Phonetic Exam Viva Pronunciation Guide
/// 9. Markdown Note Export & 1-tap Clipboard Copy
/// 10. AI Custom Formula Synthesis with KaTeX derivations
class FormulaStudioScreen extends StatefulWidget {
  final String? initialTopic;

  const FormulaStudioScreen({
    super.key,
    this.initialTopic,
  });

  @override
  State<FormulaStudioScreen> createState() => _FormulaStudioScreenState();
}

class _FormulaStudioScreenState extends State<FormulaStudioScreen> {
  final AiTutorRepository _aiRepo = AiTutorRepository();
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();

  int _currentCardIndex = 0;
  String _selectedSubject = 'All';
  bool _isCardView = true;
  bool _isGeneratingAi = false;
  String? _customAiSheetContent;

  // Bookmarking & Local Storage
  Set<String> _bookmarkedIds = {};
  static const String _bookmarksPrefsKey = 'bookmarked_formula_ids';

  // Active Recall / Self-Test Mode
  bool _isSelfTestMode = false;
  final Set<String> _revealedCardIds = {};
  int _masteredRecallCount = 0;
  int _testedRecallCount = 0;

  final List<String> _subjects = [
    'All',
    '⭐ Bookmarked',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Computer Science',
  ];

  late List<FormulaCardItem> _vaultFormulas;

  @override
  void initState() {
    super.initState();
    _initVaultData();
    _loadBookmarks();
    if (widget.initialTopic != null && widget.initialTopic!.isNotEmpty) {
      _searchController.text = widget.initialTopic!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_bookmarksPrefsKey);
      if (saved != null && mounted) {
        setState(() {
          _bookmarkedIds = saved.toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleBookmark(String formulaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (_bookmarkedIds.contains(formulaId)) {
          _bookmarkedIds.remove(formulaId);
          CustomSnackbar.showInfo(context, 'Removed from bookmarked formulas');
        } else {
          _bookmarkedIds.add(formulaId);
          CustomSnackbar.showSuccess(context, 'Saved to Bookmarked Formulas ⭐');
        }
      });
      await prefs.setStringList(_bookmarksPrefsKey, _bookmarkedIds.toList());
    } catch (_) {}
  }

  void _initVaultData() {
    _vaultFormulas = [
      // --- Mathematics & Calculus ---
      const FormulaCardItem(
        id: 'math-1',
        title: 'Fundamental Theorem of Calculus',
        subject: 'Mathematics',
        topic: 'Definite Integrals',
        latex: r'\int_a^b f(x)\,dx = F(b) - F(a) \quad \text{where } F''(x) = f(x)',
        description: 'Connects differentiation and integration, allowing evaluation of total accumulation via antiderivative boundary evaluation.',
        variables: {
          'f(x)': 'Continuous integrand on [a, b]',
          'F(x)': 'Antiderivative of f(x)',
          'a, b': 'Lower and upper integration bounds',
        },
        examTrap: 'The integrand f(x) must be continuous on [a, b]. If f(x) has an asymptotic discontinuity (e.g. 1/x^2 around x=0), standard evaluation fails!',
        derivationSummary: r'\sum f(c_i)\Delta x_i = \sum [F(x_i) - F(x_{i-1})] = F(b) - F(a)',
        shortcuts: ['Verify continuity first', 'Check symmetric bounds for odd/even functions'],
        phoneticReadout: 'Integral from a to b of f of x dx equals F of b minus F of a, where F-prime of x equals f of x.',
        calculatorType: 'calculus',
      ),
      const FormulaCardItem(
        id: 'math-2',
        title: 'Integration by Parts (LIATE Rule)',
        subject: 'Mathematics',
        topic: 'Integral Calculus',
        latex: r'\int u\,dv = u\cdot v - \int v\,du',
        description: 'Transfers derivatives between product factors to reduce complex integration into standard elementary integrals.',
        variables: {
          'u': 'Differentiable factor (chosen via LIATE)',
          'dv': 'Integrable factor with differential dx',
          'du': 'Derivative of u with respect to x',
          'v': 'Antiderivative of dv',
        },
        examTrap: 'Order of u priority strictly follows LIATE: Logarithmic, Inverse trig, Algebraic, Trigonometric, Exponential.',
        derivationSummary: r'\frac{d}{dx}(uv) = u\frac{dv}{dx} + v\frac{du}{dx} \implies \int d(uv) = \int u\,dv + \int v\,du',
        shortcuts: ['Tabular method for polynomial multiplied by exponential/sine'],
        phoneticReadout: 'Integral of u dv equals u times v minus integral of v du.',
        calculatorType: 'parts',
      ),
      const FormulaCardItem(
        id: 'math-3',
        title: 'Euler Identity & Complex Exponential',
        subject: 'Mathematics',
        topic: 'Complex Analysis',
        latex: r'e^{i\theta} = \cos(\theta) + i\sin(\theta) \implies e^{i\pi} + 1 = 0',
        description: 'Establishes the fundamental bridge between trigonometric harmonic oscillations and exponential algebra.',
        variables: {
          r'\theta': 'Phase angle in radians',
          'i': r'Imaginary unit \sqrt{-1}',
          'e': 'Euler mathematical constant (~2.71828)',
        },
        examTrap: r'Angle \theta must strictly be in radians! Using degrees leads to invalid Taylor expansion convergence.',
        derivationSummary: r'e^z = 1 + z + \frac{z^2}{2!} + \dots \implies e^{i\theta} = \cos\theta + i\sin\theta',
        shortcuts: [r'De Moivre: (\cos\theta + i\sin\theta)^n = \cos(n\theta) + i\sin(n\theta)'],
        phoneticReadout: 'e raised to the power of i theta equals cosine theta plus i sine theta. Special case: e raised to i pi plus one equals zero.',
        calculatorType: 'euler',
      ),
      const FormulaCardItem(
        id: 'math-4',
        title: 'Characteristic Equation & Matrix Eigenvalues',
        subject: 'Mathematics',
        topic: 'Linear Algebra',
        latex: r'\det(A - \lambda I) = 0 \quad \text{and} \quad A\vec{v} = \lambda\vec{v}',
        description: 'Determines invariant scalar dilation factors (eigenvalues) and directional eigenvectors under linear transformation.',
        variables: {
          'A': 'Square matrix of order n',
          r'\lambda': 'Eigenvalue scalar roots',
          'I': 'Identity matrix of order n',
          r'\vec{v}': 'Non-zero eigenvector',
        },
        examTrap: r'Sum of eigenvalues equals Trace(A); Product of eigenvalues equals \det(A). Always check with Trace test!',
        derivationSummary: r'(A - \lambda I)\vec{v} = 0 \implies \text{Non-trivial solution requires } \det(A - \lambda I) = 0',
        shortcuts: ['Trace(A) = sum of lambdas', 'Det(A) = product of lambdas'],
        phoneticReadout: 'Determinant of A minus lambda times the identity matrix equals zero, and A times vector v equals lambda times vector v.',
        calculatorType: 'matrix',
      ),

      // --- Physics & Mechanics ---
      const FormulaCardItem(
        id: 'phys-1',
        title: 'Newton Second Law for Variable Mass (Rocket Equation)',
        subject: 'Physics',
        topic: 'Classical Mechanics',
        latex: r'\vec{F}_{ext} + \vec{v}_{rel}\frac{dm}{dt} = m\frac{d\vec{v}}{dt} \implies \Delta v = v_e \ln\left(\frac{m_0}{m_f}\right)',
        description: 'Governs thrust dynamics in variable-mass open systems where mass ejection produces reactive momentum transfer.',
        variables: {
          'F_ext': 'Net external forces (Gravity, Drag) [N]',
          'v_rel': 'Relative exhaust velocity of expelled propellant [m/s]',
          'dm/dt': 'Mass burn rate (negative for consumption) [kg/s]',
          'm': 'Instantaneous total vehicle mass [kg]',
        },
        examTrap: 'F = ma fails directly for variable-mass systems! One must apply conservation of momentum to the combined system.',
        derivationSummary: r'P(t) = mv, \quad P(t+dt) = (m-dm)(v+dv) + dm(v-v_{rel}) \implies m\frac{dv}{dt} = v_{rel}\frac{dm}{dt}',
        shortcuts: ['Tsiolkovsky equation for gravity-free vacuum burn'],
        phoneticReadout: 'External force vector plus relative velocity times dm dt equals mass times dv dt. Rocket equation: Delta v equals exhaust velocity times natural log of m-zero over m-final.',
        calculatorType: 'variable_mass',
      ),
      const FormulaCardItem(
        id: 'phys-2',
        title: 'Maxwell Equations (Electromagnetic Unification)',
        subject: 'Physics',
        topic: 'Electrodynamics',
        latex: r'\oint \vec{E}\cdot d\vec{A} = \frac{Q_{enc}}{\varepsilon_0}, \quad \oint \vec{B}\cdot d\vec{\ell} = \mu_0 I + \mu_0\varepsilon_0\frac{d\Phi_E}{dt}',
        description: 'Complete set of four partial differential equations unifiying electric fields, magnetic fluxes, and electromagnetic radiation.',
        variables: {
          'E': 'Electric field intensity vector [V/m]',
          'B': 'Magnetic flux density vector [Tesla]',
          'Phi_E': 'Electric flux through enclosing boundary [V·m]',
          'eps_0, mu_0': 'Permittivity and permeability of free space',
        },
        examTrap: 'Displacement current term mu0 * eps0 * dPhi_E/dt is mandatory for time-varying fields (Ampere-Maxwell correction)!',
        derivationSummary: r'\nabla \cdot \vec{E} = \frac{\rho}{\varepsilon_0}, \quad \nabla \times \vec{E} = -\frac{\partial \vec{B}}{\partial t}, \quad \nabla \cdot \vec{B} = 0, \quad \nabla \times \vec{B} = \mu_0\vec{J} + \mu_0\varepsilon_0\frac{\partial \vec{E}}{\partial t}',
        shortcuts: [r'Electromagnetic wave speed in vacuum: c = \frac{1}{\sqrt{\varepsilon_0 \mu_0}}'],
        phoneticReadout: 'Closed surface integral of E dot dA equals enclosed charge over epsilon-zero. Closed line integral of B dot d-ell equals mu-zero I plus mu-zero epsilon-zero d-Phi-E dt.',
        calculatorType: 'maxwell',
      ),
      const FormulaCardItem(
        id: 'phys-3',
        title: 'Carnot Heat Engine Maximum Efficiency',
        subject: 'Physics',
        topic: 'Thermodynamics',
        latex: r'\eta_{Carnot} = 1 - \frac{T_C}{T_H} = \frac{W_{net}}{Q_H}',
        description: 'Defines the theoretical upper ceiling of thermodynamic efficiency achievable by any heat engine operating between two thermal reservoirs.',
        variables: {
          'eta': 'Thermodynamic thermal efficiency (0 <= eta < 1)',
          'T_C': 'Absolute cold sink reservoir temperature [Kelvin strictly]',
          'T_H': 'Absolute hot source reservoir temperature [Kelvin strictly]',
          'W_net': 'Net mechanical work output [Joules]',
        },
        examTrap: 'Temperatures must strictly be in Kelvin (K = °C + 273.15). Using Celsius (°C) is the #1 cause of lost marks!',
        derivationSummary: r'\Delta S_{cycle} = \frac{Q_H}{T_H} - \frac{Q_C}{T_C} = 0 \implies \frac{Q_C}{Q_H} = \frac{T_C}{T_H} \implies \eta = 1 - \frac{Q_C}{Q_H} = 1 - \frac{T_C}{T_H}',
        shortcuts: ['100% efficiency is impossible by Kelvin-Planck Statement'],
        phoneticReadout: 'Carnot efficiency eta equals one minus cold temperature T-sub-C divided by hot temperature T-sub-H.',
        calculatorType: 'carnot',
      ),
      const FormulaCardItem(
        id: 'phys-4',
        title: 'Bernoulli Conservation of Fluid Energy',
        subject: 'Physics',
        topic: 'Fluid Dynamics',
        latex: r'P_1 + \frac{1}{2}\rho v_1^2 + \rho g h_1 = P_2 + \frac{1}{2}\rho v_2^2 + \rho g h_2 = \text{Constant}',
        description: 'States that total mechanical energy in steady, incompressible, non-viscous fluid flow along a streamline remains invariant.',
        variables: {
          'P': 'Static hydrostatic fluid pressure [Pa = N/m²]',
          'rho': 'Fluid density [kg/m³]',
          'v': 'Streamline velocity [m/s]',
          'h': 'Geopotential elevation above reference datum [m]',
        },
        examTrap: 'Valid only for streamline laminar flow without viscous friction losses (head loss). Not valid across pumps or turbines without head terms!',
        derivationSummary: r'W_{net} = \Delta K + \Delta U \implies (P_1 - P_2)V = \frac{1}{2}m(v_2^2 - v_1^2) + mg(h_2 - h_1)',
        shortcuts: ['Dynamic pressure term = 1/2 rho v^2', 'Torricelli speed v = sqrt(2gh)'],
        phoneticReadout: 'Pressure P plus one-half rho v squared plus rho g h equals constant along a streamline.',
        calculatorType: 'bernoulli',
      ),

      // --- Computer Science & Algorithms ---
      const FormulaCardItem(
        id: 'cs-1',
        title: 'Master Theorem for Divide & Conquer',
        subject: 'Computer Science',
        topic: 'Algorithms & Complexity',
        latex: r'T(n) = a\,T\left(\frac{n}{b}\right) + \Theta(n^k \log^p n) \implies c = \log_b a',
        description: 'Provides closed-form asymptotic Big-O runtime bounds for recursive recurrence relations in divide-and-conquer algorithms.',
        variables: {
          'a': 'Number of recursive subproblems per step (a >= 1)',
          'b': 'Factor by which input size is divided (b > 1)',
          'k': 'Polynomial exponent of work done outside recursion (k >= 0)',
          'c = log_b(a)': 'Critical watershed exponent',
        },
        examTrap: 'Check if c > k (Case 1: O(n^c)), c == k (Case 2: O(n^k log^(p+1) n)), or c < k with regularity condition (Case 3: O(n^k log^p n)).',
        derivationSummary: r'\sum_{j=0}^{\log_b n} a^j \left(\frac{n}{b^j}\right)^k = n^k \sum_{j=0}^{\log_b n} \left(\frac{a}{b^k}\right)^j',
        shortcuts: ['Merge Sort: a=2, b=2, k=1 -> O(n log n)', 'Binary Search: a=1, b=2, k=0 -> O(log n)'],
        phoneticReadout: 'T of n equals a times T of n over b plus Theta of n to the k times log to the p of n. Critical exponent c equals log base b of a.',
        calculatorType: 'master_theorem',
      ),
      const FormulaCardItem(
        id: 'cs-2',
        title: 'Shannon Information Entropy',
        subject: 'Computer Science',
        topic: 'Information Theory',
        latex: r'H(X) = -\sum_{i=1}^n P(x_i)\log_2 P(x_i) = \sum_{i=1}^n P(x_i)\log_2\left(\frac{1}{P(x_i)}\right)',
        description: 'Quantifies expected information density, uncertainty, and minimal lossless compression limit per symbol in bits.',
        variables: {
          'H(X)': 'Entropy in bits (or shannons) [bits/symbol]',
          'P(x_i)': 'Probability of occurrence for event i (sum = 1.0)',
          'log_2': 'Base-2 logarithm representing binary encoding bits',
        },
        examTrap: 'If P(x_i) = 0, the term is evaluated as 0 because lim (p -> 0) of p * log2(p) = 0. Maximum entropy occurs with uniform distribution: H_max = log2(n).',
        derivationSummary: r'I(x) = \log_2(1/P(x)) \implies H(X) = \mathbb{E}[I(x)] = \sum P(x_i) \log_2(1/P(x_i))',
        shortcuts: ['Fair coin: H = 1 bit', 'Biased coin P=0.9: H = 0.47 bits'],
        phoneticReadout: 'Entropy H of X equals minus sum over i of P of x-sub-i times log base two of P of x-sub-i.',
        calculatorType: 'shannon_entropy',
      ),

      // --- Chemistry & Physical Sciences ---
      const FormulaCardItem(
        id: 'chem-1',
        title: 'Gibbs Free Energy & Reaction Spontaneity',
        subject: 'Chemistry',
        topic: 'Chemical Thermodynamics',
        latex: r'\Delta G = \Delta H - T\Delta S \quad \text{and} \quad \Delta G^\circ = -RT\ln K_{eq}',
        description: 'Governs thermodynamic feasibility and directionality of chemical processes under constant temperature and pressure.',
        variables: {
          'Delta G': 'Gibbs free energy change (Negative = Spontaneous) [kJ/mol]',
          'Delta H': 'Enthalpy change (Negative = Exothermic) [kJ/mol]',
          'T': 'Absolute temperature in Kelvin [K]',
          'Delta S': 'Entropy change of system [J/(mol·K)] - Note unit mismatch!',
        },
        examTrap: 'UNIT TRAP: Delta H is typically in kJ/mol while Delta S is in J/(mol·K). Divide Delta S by 1000 before subtracting!',
        derivationSummary: r'\Delta S_{univ} = \Delta S_{sys} + \Delta S_{surr} = \Delta S_{sys} - \frac{\Delta H_{sys}}{T} > 0 \implies \Delta H - T\Delta S < 0',
        shortcuts: ['Delta H < 0, Delta S > 0: Spontaneous at all temperatures', 'Delta H > 0, Delta S < 0: Non-spontaneous at all temperatures'],
        phoneticReadout: 'Delta G equals Delta H minus T times Delta S. Standard state: Delta G naught equals minus R T times natural log of K equilibrium.',
        calculatorType: 'gibbs',
      ),
      const FormulaCardItem(
        id: 'chem-2',
        title: 'Nernst Equation for Electrochemical Cell Potential',
        subject: 'Chemistry',
        topic: 'Electrochemistry',
        latex: r'E_{cell} = E^\circ_{cell} - \frac{RT}{nF}\ln Q = E^\circ_{cell} - \frac{0.0592}{n}\log_{10} Q \quad (\text{at } 298\,\text{K})',
        description: 'Calculates non-standard reduction potential of electrochemical galvanic and electrolytic cells as reactant concentrations shift.',
        variables: {
          'E_cell': 'Actual cell electromotive force [Volts]',
          'E_0_cell': 'Standard reduction potential under 1M, 1atm [Volts]',
          'n': 'Number of moles of electrons transferred in redox reaction',
          'Q': 'Reaction quotient [Products]^c / [Reactants]^a',
        },
        examTrap: 'Pure solids and liquids do NOT appear in the expression for Q! Ensure the redox reaction is strictly balanced before finding n.',
        derivationSummary: r'\Delta G = \Delta G^\circ + RT\ln Q \quad \text{with } \Delta G = -nFE_{cell} \implies -nFE = -nFE^\circ + RT\ln Q',
        shortcuts: ['At equilibrium, E_cell = 0 and Q = K_eq'],
        phoneticReadout: 'E cell equals E naught cell minus zero point zero five nine two over n times log base ten of Q at 298 Kelvin.',
        calculatorType: 'nernst',
      ),
    ];
  }

  List<FormulaCardItem> get _filteredFormulas {
    final query = _searchController.text.trim().toLowerCase();
    return _vaultFormulas.where((item) {
      if (_selectedSubject == '⭐ Bookmarked') {
        if (!_bookmarkedIds.contains(item.id)) return false;
      } else if (_selectedSubject != 'All' && item.subject != _selectedSubject) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.topic.toLowerCase().contains(query) ||
          item.subject.toLowerCase().contains(query) ||
          item.latex.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.variables.keys.any((k) => k.toLowerCase().contains(query)) ||
          item.variables.values.any((v) => v.toLowerCase().contains(query));
    }).toList();
  }

  void _goToCard(int index) {
    if (index >= 0 && index < _filteredFormulas.length) {
      setState(() {
        _currentCardIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _handleCustomAiSynthesize(String topic) async {
    setState(() {
      _isGeneratingAi = true;
      _customAiSheetContent = null;
    });

    try {
      final prompt = 'Generate an exhaustive, high-yield Academic Formula Sheet and Theorem Breakdown for: "$topic".\n'
          r'Format with LaTeX mathematical equations using $$ equation $$, variable definitions with SI units, potential examiner traps, and analytical proofs.';
      final response = await _aiRepo.askDoubt(
        question: prompt,
        mode: 'formula_vault',
      );
      if (mounted) {
        setState(() {
          _customAiSheetContent = response.content;
          _isGeneratingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
        CustomSnackbar.showError(context, 'Failed to generate formula sheet: $e');
      }
    }
  }

  void _showAiPromptDialog() {
    final textCtrl = TextEditingController(text: _searchController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primary),
            SizedBox(width: 8),
            Text('AI Formula Synthesizer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter any academic topic, equation name, or concept to generate a verified formula sheet:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Fourier Transform, Kirchhoff Laws, Quantum Wavefunction',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final t = textCtrl.text.trim();
              Navigator.pop(ctx);
              if (t.isNotEmpty) {
                _handleCustomAiSynthesize(t);
              }
            },
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Generate Sheet'),
          ),
        ],
      ),
    );
  }

  void _copyFullFormulaMarkdown(FormulaCardItem item) {
    final buffer = StringBuffer();
    buffer.writeln('# ${item.title} (${item.subject} - ${item.topic})');
    buffer.writeln();
    buffer.writeln('### Mathematical Formula');
    buffer.writeln(r'$$');
    buffer.writeln(item.latex);
    buffer.writeln(r'$$');
    buffer.writeln();
    buffer.writeln('**Description:** ${item.description}');
    buffer.writeln();
    if (item.phoneticReadout.isNotEmpty) {
      buffer.writeln('**Phonetic Pronunciation:** "${item.phoneticReadout}"');
      buffer.writeln();
    }
    if (item.variables.isNotEmpty) {
      buffer.writeln('### Variables & Dimensions');
      item.variables.forEach((k, v) {
        buffer.writeln('- `$k`: $v');
      });
      buffer.writeln();
    }
    if (item.examTrap.isNotEmpty) {
      buffer.writeln('> ⚠️ **Examiner Trap Warning:** ${item.examTrap}');
      buffer.writeln();
    }
    if (item.derivationSummary.isNotEmpty) {
      buffer.writeln('### Analytical Derivation');
      buffer.writeln(r'$$');
      buffer.writeln(item.derivationSummary);
      buffer.writeln(r'$$');
      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    CustomSnackbar.showSuccess(context, 'Complete Markdown summary copied to clipboard! 📋');
  }

  // --- Interactive Scientific Formula Solver Modal ---
  void _openFormulaSolver(FormulaCardItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FormulaInteractiveSolverModal(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredFormulas;

    if (_currentCardIndex >= filtered.length && filtered.isNotEmpty) {
      _currentCardIndex = filtered.length - 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Formula Studio & Vault',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () => context.pop(),
        ),
        actions: [
          // Self-Test / Flashcard Mode Toggle
          IconButton(
            icon: Icon(
              _isSelfTestMode ? Icons.psychology : Icons.psychology_outlined,
              color: _isSelfTestMode ? Colors.amber : null,
            ),
            tooltip: _isSelfTestMode ? 'Self-Test Mode Active (Tap to disable)' : 'Enable Active Recall Self-Test Mode',
            onPressed: () {
              setState(() {
                _isSelfTestMode = !_isSelfTestMode;
                _revealedCardIds.clear();
              });
              if (_isSelfTestMode) {
                CustomSnackbar.showInfo(context, '🧠 Self-Test Active: Formulas are masked for recall practice!');
              }
            },
          ),
          // View Mode Toggle (Card Deck vs List View)
          IconButton(
            icon: Icon(_isCardView ? Icons.view_headline_rounded : Icons.view_carousel_rounded),
            tooltip: _isCardView ? 'Switch to Sheet / List View' : 'Switch to Card Deck Carousel',
            onPressed: () {
              setState(() {
                _isCardView = !_isCardView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
            tooltip: 'AI Synthesize Custom Topic',
            onPressed: _showAiPromptDialog,
          ),
        ],
      ),
      bottomNavigationBar: _isCardView && filtered.isNotEmpty
          ? _buildBottomNavigationControls(filtered, isDark)
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search formula, theorem, or variable...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _currentCardIndex = 0;
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) {
                          setState(() {
                            _currentCardIndex = 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showAiPromptDialog,
                      icon: const Icon(Icons.bolt, size: 16),
                      label: const Text('AI Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),

              // Subject Filter Chips Bar
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _subjects.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final sub = _subjects[index];
                    final isSelected = _selectedSubject == sub;
                    final isBookmarkChip = sub == '⭐ Bookmarked';
                    final label = isBookmarkChip ? '⭐ Bookmarked (${_bookmarkedIds.length})' : sub;

                    return FilterChip(
                      selected: isSelected,
                      label: Text(label),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      selectedColor: isBookmarkChip ? Colors.amber[700] : AppColors.primary,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) {
                        setState(() {
                          _selectedSubject = sub;
                          _currentCardIndex = 0;
                        });
                        if (_isCardView && _pageController.hasClients) {
                          _pageController.jumpToPage(0);
                        }
                      },
                    );
                  },
                ),
              ),

              // Active Recall Session Score Banner (when in Self-Test Mode)
              if (_isSelfTestMode)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Active Recall Mode: ${_testedRecallCount == 0 ? "Test your memory" : "$_masteredRecallCount / $_testedRecallCount Mastered"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ],
                      ),
                      if (_testedRecallCount > 0)
                        Text(
                          '${((_masteredRecallCount / _testedRecallCount) * 100).toStringAsFixed(0)}% Accuracy',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Custom AI Sheet Result or Main Views
              Expanded(
                child: _isGeneratingAi
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text('AI Synthesizing Academic Formula Sheet...', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 6),
                            Text('Deriving LaTeX proofs, dimensional matrices & examiner warnings', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    : _customAiSheetContent != null
                        ? _buildCustomAiSheetView(isDark)
                        : filtered.isEmpty
                            ? _buildEmptyState(isDark)
                            : _isCardView
                                ? _buildCardDeckView(filtered, isDark)
                                : _buildListView(filtered, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. Interactive Card Deck Mode with Swipe ---
  Widget _buildCardDeckView(List<FormulaCardItem> items, bool isDark) {
    return PageView.builder(
      controller: _pageController,
      itemCount: items.length,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (idx) {
        setState(() {
          _currentCardIndex = idx;
        });
      },
      itemBuilder: (context, index) {
        final item = items[index];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: _buildFormulaDetailCard(item, index + 1, items.length, isDark),
        );
      },
    );
  }

  // --- 2. Prominent Previous & Next Navigation Controls ---
  Widget _buildBottomNavigationControls(List<FormulaCardItem> items, bool isDark) {
    final canPrev = _currentCardIndex > 0;
    final canNext = _currentCardIndex < items.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous Button (Piche)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canPrev ? () => _goToCard(_currentCardIndex - 1) : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            // Step Indicator: "Formula X of Y"
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Formula ${_currentCardIndex + 1} of ${items.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    items.length > 8 ? 8 : items.length,
                    (dotIdx) {
                      final activeDot = (dotIdx == (_currentCardIndex % (items.length > 8 ? 8 : items.length)));
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: activeDot ? 12 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: activeDot ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Next Button (Aage)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canNext ? () => _goToCard(_currentCardIndex + 1) : null,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Rich Formula Presentation Card ---
  Widget _buildFormulaDetailCard(FormulaCardItem item, int currentNum, int totalCount, bool isDark) {
    final isBookmarked = _bookmarkedIds.contains(item.id);
    final isRevealed = !_isSelfTestMode || _revealedCardIds.contains(item.id);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with badges & quick actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.subject.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.topic,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Bookmark Toggle Button
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
                    color: isBookmarked ? Colors.amber : (isDark ? Colors.white60 : Colors.black54),
                    size: 20,
                  ),
                  tooltip: isBookmarked ? 'Remove Bookmark' : 'Save to Bookmarks',
                  onPressed: () => _toggleBookmark(item.id),
                ),
                // Export / Copy Markdown
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  tooltip: 'Export Markdown Summary',
                  onPressed: () => _copyFullFormulaMarkdown(item),
                ),
                Text(
                  '#$currentNum of $totalCount',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
                const SizedBox(height: 14),

                // Phonetic Exam / Viva Pronunciation Guide
                if (item.phoneticReadout.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.record_voice_over_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Exam Viva Readout: "${item.phoneticReadout}"',
                            style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Active Recall Challenge Box (if in Self-Test Mode and unrevealed)
                if (!isRevealed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock_clock, color: Colors.amber, size: 36),
                        const SizedBox(height: 10),
                        const Text(
                          'Active Recall Challenge',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Before revealing, state the mathematical formula, define its parameters, and recall potential examiner traps in your mind or on paper!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _revealedCardIds.add(item.id);
                            });
                          },
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          label: const Text('Reveal Formula & Solution', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  // Main Math Formula Display Box (KaTeX)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.4 : 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'EQUATION & THEOREM FORMULA',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7), letterSpacing: 0.6),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0284C7)),
                              tooltip: 'Copy LaTeX Formula',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: item.latex));
                                CustomSnackbar.showSuccess(context, 'LaTeX formula copied to clipboard!');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Math.tex(
                            item.latex,
                            textStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            ),
                            mathStyle: MathStyle.display,
                            onErrorFallback: (_) => Text(
                              item.latex,
                              style: GoogleFonts.firaCode(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Variables & SI Units Table
                  if (item.variables.isNotEmpty) ...[
                    const Text('Variables & Physical Dimensions:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: item.variables.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    e.key,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                                    ),
                                  ),
                                ),
                                const Text(': ', style: TextStyle(color: Colors.grey)),
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Examiner Trap Alert Box
                  if (item.examTrap.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Examiner Trap Warning:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning)),
                                const SizedBox(height: 2),
                                Text(item.examTrap, style: const TextStyle(fontSize: 12, color: AppColors.warning)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Derivation / Proof Summary
                  if (item.derivationSummary.isNotEmpty) ...[
                    const Text('Proof & Analytical Derivation:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Math.tex(
                          item.derivationSummary,
                          textStyle: TextStyle(fontSize: 13.5, color: isDark ? Colors.white70 : Colors.black87),
                          onErrorFallback: (_) => Text(item.derivationSummary, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Active Recall Assessment Rating (if in self-test mode)
                  if (_isSelfTestMode) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'How was your recall?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.success),
                            onPressed: () {
                              setState(() {
                                _masteredRecallCount++;
                                _testedRecallCount++;
                              });
                              CustomSnackbar.showSuccess(context, 'Great job! Marked as Mastered ✅');
                              if (_currentCardIndex < _filteredFormulas.length - 1) {
                                _goToCard(_currentCardIndex + 1);
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Mastered'),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                            onPressed: () {
                              setState(() {
                                _testedRecallCount++;
                                if (!_bookmarkedIds.contains(item.id)) {
                                  _bookmarkedIds.add(item.id);
                                }
                              });
                              CustomSnackbar.showInfo(context, 'Added to Bookmarks for revision 🔄');
                            },
                            icon: const Icon(Icons.replay_rounded, size: 16),
                            label: const Text('Needs Practice'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                // Action Bar: Interactive Solver + AI Deep Explain + Quiz Practice
                Row(
                  children: [
                    // Interactive Solver Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.calculate_outlined, size: 18),
                        label: const Text('Interactive Solver', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        onPressed: () => _openFormulaSolver(item),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Explain in AI Tutor
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.psychology, size: 18),
                        label: const Text('AI Explanation', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          context.push(AppRoutes.aiChat, extra: {
                            'initialQuery': 'Please provide an exhaustive academic derivation, real-world engineering intuition, and numerical example for:\n\n${item.title}\n\nLaTeX: ${item.latex}',
                            'noteTitle': item.title,
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Practice in Quiz
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.quiz_outlined, size: 18),
                        label: const Text('Practice Quiz', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          context.push(AppRoutes.quizzes, extra: {
                            'title': item.topic,
                            'topic': item.topic,
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Sheet / List View Mode ---
  Widget _buildListView(List<FormulaCardItem> items, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final isBookmarked = _bookmarkedIds.contains(item.id);

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _isCardView = true;
              _currentCardIndex = index;
            });
            _pageController.jumpToPage(index);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: isBookmarked ? Colors.amber : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => _toggleBookmark(item.id),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.subject,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    item.latex,
                    textStyle: TextStyle(
                      fontSize: 16,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openFormulaSolver(item),
                      icon: const Icon(Icons.calculate_outlined, size: 16),
                      label: const Text('Solver', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to open card →',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 5. AI Generated Topic View ---
  Widget _buildCustomAiSheetView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('AI Synthesized Formula Sheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _customAiSheetContent = null;
                  });
                },
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Back to Vault'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: FormattedAiText(
              text: _customAiSheetContent ?? '',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Empty State ---
  Widget _buildEmptyState(bool isDark) {
    final isBookmarkView = _selectedSubject == '⭐ Bookmarked';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBookmarkView ? Icons.bookmark_border_rounded : Icons.search_off_rounded,
              size: 56,
              color: isBookmarkView ? Colors.amber : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isBookmarkView ? 'No Bookmarked Formulas Yet' : 'No Formulas Found',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              isBookmarkView
                  ? 'Tap the bookmark icon on any formula card to save it here for fast exam revision.'
                  : 'No equations match "${_searchController.text}". Generate a dedicated sheet with AI!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (isBookmarkView) {
                  setState(() {
                    _selectedSubject = 'All';
                  });
                } else {
                  _showAiPromptDialog();
                }
              },
              icon: Icon(isBookmarkView ? Icons.list_alt : Icons.bolt, size: 18),
              label: Text(isBookmarkView ? 'Browse All Formulas' : 'Synthesize With AI', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// --- Interactive Scientific Formula Solver Modal ---
class _FormulaInteractiveSolverModal extends StatefulWidget {
  final FormulaCardItem item;

  const _FormulaInteractiveSolverModal({required this.item});

  @override
  State<_FormulaInteractiveSolverModal> createState() => _FormulaInteractiveSolverModalState();
}

class _FormulaInteractiveSolverModalState extends State<_FormulaInteractiveSolverModal> {
  // Newton 2nd Law / Rocket: F = m*a + v_rel*(dm/dt)
  double _rocketMass = 1000.0;
  double _rocketAccel = 9.81;
  double _rocketVrel = 2500.0;
  double _rocketDmdt = 12.5;

  // Carnot: eta = 1 - Tc / Th
  double _carnotTc = 300.0; // K
  double _carnotTh = 600.0; // K

  // Euler: e^(i theta) = cos(theta) + i sin(theta)
  double _eulerAngleDeg = 45.0;

  // Master Theorem: T(n) = a T(n/b) + Theta(n^k log^p n)
  double _masterA = 2.0;
  double _masterB = 2.0;
  double _masterK = 1.0;
  double _masterP = 0.0;

  // Shannon Entropy: H = - sum(p * log2(p))
  String _shannonInput = '0.5, 0.5';

  // Gibbs: Delta G = Delta H - T * Delta S
  double _gibbsDeltaH = -50.0; // kJ/mol
  double _gibbsTemp = 298.15;  // K
  double _gibbsDeltaS = -100.0;// J/(mol*K)

  // Nernst: E = E0 - (0.0592 / n) * log10(Q)
  double _nernstE0 = 1.10; // V (Daniell cell standard)
  double _nernstN = 2.0;
  double _nernstQ = 0.1;

  // Bernoulli: Delta P = 0.5 * rho * (v2^2 - v1^2) + rho * g * (h2 - h1)
  double _bernRho = 1000.0; // kg/m^3
  double _bernV1 = 2.0;
  double _bernV2 = 5.0;
  double _bernDeltaH = 0.0;

  // Universal dynamic map for any other formula
  final Map<String, double> _universalValues = {};

  @override
  void initState() {
    super.initState();
    for (final key in widget.item.variables.keys) {
      _universalValues[key] = 1.0;
    }
  }

  Widget _buildNumberInput({
    required String label,
    required double initialValue,
    required ValueChanged<double> onChanged,
    String? unit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              unit != null ? '$label ($unit)' : label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: initialValue.toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (val) {
                final d = double.tryParse(val);
                if (d != null) {
                  setState(() => onChanged(d));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Text(
                      'Interactive Solver',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0284C7)),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                item.latex,
                textStyle: const TextStyle(fontSize: 16, color: Color(0xFF0284C7)),
              ),
            ),
            const Divider(height: 24),

            // Dynamic Solver Specific to Formula
            if (item.calculatorType == 'carnot') ...[
              _buildNumberInput(
                label: 'Cold Reservoir (T_C)',
                unit: 'Kelvin',
                initialValue: _carnotTc,
                onChanged: (v) => _carnotTc = v,
              ),
              _buildNumberInput(
                label: 'Hot Reservoir (T_H)',
                unit: 'Kelvin',
                initialValue: _carnotTh,
                onChanged: (v) => _carnotTh = v,
              ),
              _buildCarnotResult(isDark),
            ] else if (item.calculatorType == 'variable_mass') ...[
              _buildNumberInput(label: 'Total Mass (m)', unit: 'kg', initialValue: _rocketMass, onChanged: (v) => _rocketMass = v),
              _buildNumberInput(label: 'Acceleration (a)', unit: 'm/s²', initialValue: _rocketAccel, onChanged: (v) => _rocketAccel = v),
              _buildNumberInput(label: 'Relative Velocity (v_rel)', unit: 'm/s', initialValue: _rocketVrel, onChanged: (v) => _rocketVrel = v),
              _buildNumberInput(label: 'Burn Rate (dm/dt)', unit: 'kg/s', initialValue: _rocketDmdt, onChanged: (v) => _rocketDmdt = v),
              _buildRocketResult(isDark),
            ] else if (item.calculatorType == 'euler') ...[
              _buildNumberInput(label: 'Angle (theta)', unit: 'degrees', initialValue: _eulerAngleDeg, onChanged: (v) => _eulerAngleDeg = v),
              _buildEulerResult(isDark),
            ] else if (item.calculatorType == 'master_theorem') ...[
              _buildNumberInput(label: 'Subproblems (a)', initialValue: _masterA, onChanged: (v) => _masterA = v),
              _buildNumberInput(label: 'Division Factor (b)', initialValue: _masterB, onChanged: (v) => _masterB = v),
              _buildNumberInput(label: 'Work Exponent (k)', initialValue: _masterK, onChanged: (v) => _masterK = v),
              _buildNumberInput(label: 'Log Exponent (p)', initialValue: _masterP, onChanged: (v) => _masterP = v),
              _buildMasterTheoremResult(isDark),
            ] else if (item.calculatorType == 'shannon_entropy') ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: TextEditingController(text: _shannonInput),
                  decoration: InputDecoration(
                    labelText: 'Symbol Probabilities (comma-separated)',
                    hintText: 'e.g. 0.5, 0.5 or 0.25, 0.25, 0.5',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _shannonInput = v),
                ),
              ),
              _buildShannonResult(isDark),
            ] else if (item.calculatorType == 'gibbs') ...[
              _buildNumberInput(label: 'Enthalpy (Delta H)', unit: 'kJ/mol', initialValue: _gibbsDeltaH, onChanged: (v) => _gibbsDeltaH = v),
              _buildNumberInput(label: 'Temperature (T)', unit: 'K', initialValue: _gibbsTemp, onChanged: (v) => _gibbsTemp = v),
              _buildNumberInput(label: 'Entropy (Delta S)', unit: 'J/(mol·K)', initialValue: _gibbsDeltaS, onChanged: (v) => _gibbsDeltaS = v),
              _buildGibbsResult(isDark),
            ] else if (item.calculatorType == 'nernst') ...[
              _buildNumberInput(label: 'Standard E°', unit: 'Volts', initialValue: _nernstE0, onChanged: (v) => _nernstE0 = v),
              _buildNumberInput(label: 'Electrons Transferred (n)', initialValue: _nernstN, onChanged: (v) => _nernstN = v),
              _buildNumberInput(label: 'Reaction Quotient (Q)', initialValue: _nernstQ, onChanged: (v) => _nernstQ = v),
              _buildNernstResult(isDark),
            ] else if (item.calculatorType == 'bernoulli') ...[
              _buildNumberInput(label: 'Fluid Density (rho)', unit: 'kg/m³', initialValue: _bernRho, onChanged: (v) => _bernRho = v),
              _buildNumberInput(label: 'Initial Velocity (v1)', unit: 'm/s', initialValue: _bernV1, onChanged: (v) => _bernV1 = v),
              _buildNumberInput(label: 'Final Velocity (v2)', unit: 'm/s', initialValue: _bernV2, onChanged: (v) => _bernV2 = v),
              _buildNumberInput(label: 'Height Diff (h2 - h1)', unit: 'meters', initialValue: _bernDeltaH, onChanged: (v) => _bernDeltaH = v),
              _buildBernoulliResult(isDark),
            ] else ...[
              // Universal Dynamic Evaluator
              const Text('Set parameter values to evaluate relationship:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              for (final entry in item.variables.entries)
                _buildNumberInput(
                  label: entry.key,
                  unit: entry.value,
                  initialValue: _universalValues[entry.key] ?? 1.0,
                  onChanged: (v) => _universalValues[entry.key] = v,
                ),
              _buildUniversalResult(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultBox({
    required String title,
    required String result,
    required String explanation,
    required bool isDark,
    Color? accentColor,
  }) {
    final color = accentColor ?? const Color(0xFF0284C7);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(result, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(explanation, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildCarnotResult(bool isDark) {
    if (_carnotTh <= 0 || _carnotTc < 0 || _carnotTc > _carnotTh) {
      return _buildResultBox(
        title: 'Error in Reservoir Temperatures',
        result: 'Invalid Thermal Values',
        explanation: 'Th must be strictly greater than Tc, and temperatures must be > 0 Kelvin.',
        isDark: isDark,
        accentColor: AppColors.error,
      );
    }
    final eta = 1.0 - (_carnotTc / _carnotTh);
    final percent = (eta * 100.0).toStringAsFixed(2);
    return _buildResultBox(
      title: 'Carnot Reversible Efficiency Limit',
      result: 'eta = $percent%',
      explanation: 'Theoretical ceiling: For every 100 Joules of heat supplied at $_carnotTh K, maximum $percent J can be converted to work, while ${(100 - double.parse(percent)).toStringAsFixed(2)} J is expelled at $_carnotTc K.',
      isDark: isDark,
      accentColor: AppColors.success,
    );
  }

  Widget _buildRocketResult(bool isDark) {
    final thrust = (_rocketVrel * _rocketDmdt);
    final totalF = (_rocketMass * _rocketAccel) + thrust;
    return _buildResultBox(
      title: 'Reactive Momentum Thrust Output',
      result: 'Net Thrust F = ${totalF.toStringAsFixed(1)} N (${(totalF / 1000).toStringAsFixed(2)} kN)',
      explanation: 'Propellant reaction thrust = v_rel * (dm/dt) = ${thrust.toStringAsFixed(1)} N. Inertial resistance = ${( _rocketMass * _rocketAccel).toStringAsFixed(1)} N.',
      isDark: isDark,
    );
  }

  Widget _buildEulerResult(bool isDark) {
    final rad = _eulerAngleDeg * (math.pi / 180.0);
    final cosVal = math.cos(rad);
    final sinVal = math.sin(rad);
    final sign = sinVal >= 0 ? '+' : '-';
    return _buildResultBox(
      title: 'Euler Phasor Representation',
      result: 'z = ${cosVal.toStringAsFixed(3)} $sign ${sinVal.abs().toStringAsFixed(3)} i',
      explanation: 'Modulus |z| = 1.0 (Unit circle invariant). Real coordinate = cos($_eulerAngleDeg°) = ${cosVal.toStringAsFixed(3)}, Imaginary = sin($_eulerAngleDeg°) = ${sinVal.toStringAsFixed(3)}.',
      isDark: isDark,
    );
  }

  Widget _buildMasterTheoremResult(bool isDark) {
    if (_masterA < 1 || _masterB <= 1) {
      return _buildResultBox(
        title: 'Master Theorem Constraint',
        result: 'Invalid Recurrence',
        explanation: 'Requires a >= 1 and b > 1.',
        isDark: isDark,
        accentColor: AppColors.error,
      );
    }
    final c = math.log(_masterA) / math.log(_masterB);
    final diff = c - _masterK;

    String caseStr;
    String complexity;
    if (diff > 0.001) {
      caseStr = 'Case 1 (Leaf / Recursion Heavy: c > k)';
      complexity = 'Theta(n^${c.toStringAsFixed(2)})';
    } else if (diff.abs() <= 0.001) {
      caseStr = 'Case 2 (Balanced Work: c == k)';
      complexity = _masterP == 0 ? 'Theta(n^${_masterK.toStringAsFixed(0)} log n)' : 'Theta(n^${_masterK.toStringAsFixed(0)} log^${(_masterP + 1).toStringAsFixed(0)} n)';
    } else {
      caseStr = 'Case 3 (Root / Partition Heavy: c < k)';
      complexity = 'Theta(n^${_masterK.toStringAsFixed(0)})';
    }

    return _buildResultBox(
      title: 'Algorithm Asymptotic Complexity ($caseStr)',
      result: 'T(n) = $complexity',
      explanation: 'Watershed critical exponent c = log_b(a) = log_$_masterB($_masterA) = ${c.toStringAsFixed(3)}. External work exponent k = $_masterK.',
      isDark: isDark,
      accentColor: AppColors.primary,
    );
  }

  Widget _buildShannonResult(bool isDark) {
    final parts = _shannonInput.split(',').map((s) => double.tryParse(s.trim())).where((d) => d != null && d > 0).toList();
    if (parts.isEmpty) {
      return _buildResultBox(title: 'Shannon Entropy', result: 'Enter valid probabilities', explanation: 'e.g. 0.5, 0.5', isDark: isDark);
    }
    final sum = parts.fold<double>(0.0, (acc, val) => acc + val!);
    double entropy = 0.0;
    for (final p in parts) {
      final normalized = p! / sum;
      entropy += -normalized * (math.log(normalized) / math.ln2);
    }
    final maxEntropy = math.log(parts.length) / math.ln2;
    return _buildResultBox(
      title: 'Information Content & Uncertainty',
      result: 'H(X) = ${entropy.toStringAsFixed(3)} bits/symbol',
      explanation: 'Max theoretical entropy for ${parts.length} symbols = ${maxEntropy.toStringAsFixed(3)} bits. Compression redundancy = ${(1.0 - (entropy / (maxEntropy > 0 ? maxEntropy : 1.0))) * 100.0}%',
      isDark: isDark,
    );
  }

  Widget _buildGibbsResult(bool isDark) {
    // Delta G = Delta H - (T * Delta S / 1000)
    final deltaG = _gibbsDeltaH - (_gibbsTemp * (_gibbsDeltaS / 1000.0));
    final spontaneous = deltaG < 0;
    final eq = deltaG.abs() < 0.001;

    return _buildResultBox(
      title: 'Chemical Thermodynamic Feasibility',
      result: 'Delta G = ${deltaG.toStringAsFixed(2)} kJ/mol',
      explanation: eq
          ? 'System is at Dynamic Equilibrium (Delta G = 0).'
          : spontaneous
              ? 'Reaction is SPONTANEOUS (Exergonic forward process).'
              : 'Reaction is NON-SPONTANEOUS (Endergonic; requires external work/voltage).',
      isDark: isDark,
      accentColor: spontaneous ? AppColors.success : AppColors.error,
    );
  }

  Widget _buildNernstResult(bool isDark) {
    if (_nernstN <= 0 || _nernstQ <= 0) {
      return _buildResultBox(
        title: 'Nernst Constraint',
        result: 'Invalid Parameters',
        explanation: 'Electrons n must be > 0 and reaction quotient Q must be > 0.',
        isDark: isDark,
        accentColor: AppColors.error,
      );
    }
    final eCell = _nernstE0 - ((0.0592 / _nernstN) * (math.log(_nernstQ) / math.ln10));
    return _buildResultBox(
      title: 'Electrochemical Cell EMF Potential',
      result: 'E_cell = ${eCell.toStringAsFixed(3)} V',
      explanation: 'Standard E° = ${_nernstE0}V with n = ${_nernstN.toStringAsFixed(0)}e⁻ transfer. When Q = $_nernstQ, Nernst concentration shift = ${((0.0592 / _nernstN) * (math.log(_nernstQ) / math.ln10)).toStringAsFixed(3)} V.',
      isDark: isDark,
      accentColor: eCell > 0 ? AppColors.success : AppColors.error,
    );
  }

  Widget _buildBernoulliResult(bool isDark) {
    // Delta P = P1 - P2 = 0.5 * rho * (v2^2 - v1^2) + rho * g * Delta H
    final deltaP = (0.5 * _bernRho * ((_bernV2 * _bernV2) - (_bernV1 * _bernV1))) + (_bernRho * 9.81 * _bernDeltaH);
    return _buildResultBox(
      title: 'Bernoulli Static Pressure Differential',
      result: 'Delta P = ${deltaP.toStringAsFixed(1)} Pa (${(deltaP / 1000.0).toStringAsFixed(2)} kPa)',
      explanation: 'Dynamic kinetic head shift = ${(0.5 * _bernRho * ((_bernV2 * _bernV2) - (_bernV1 * _bernV1))).toStringAsFixed(1)} Pa. Potential geopotential head shift = ${(_bernRho * 9.81 * _bernDeltaH).toStringAsFixed(1)} Pa.',
      isDark: isDark,
    );
  }

  Widget _buildUniversalResult(bool isDark) {
    return _buildResultBox(
      title: 'Parametric State Evaluation',
      result: 'Variables Adjusted (${_universalValues.length} active)',
      explanation: 'Use AI Tutor chat or Practice Quiz to simulate boundary conditions and multi-variable asymptotic limits for this theorem.',
      isDark: isDark,
    );
  }
}
