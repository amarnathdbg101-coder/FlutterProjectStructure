/// Universal LaTeX & Backslash Sanitizer for StudySilo
/// Elegantly transforms LaTeX commands, scientific notation, and accidental backslashes
/// into clean, readable Unicode and human prose without raw code leakage.
class LatexSanitizer {
  // ⚡ Comprehensive Greek Alphabet Map (lowercase & uppercase)
  static const Map<String, String> _greekMap = {
    'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'Gamma': 'Γ',
    'delta': 'δ', 'Delta': 'Δ', 'epsilon': 'ε', 'varepsilon': 'ε',
    'zeta': 'ζ', 'eta': 'η', 'theta': 'θ', 'vartheta': 'ϑ', 'Theta': 'Θ',
    'iota': 'ι', 'kappa': 'κ', 'lambda': 'λ', 'Lambda': 'Λ',
    'mu': 'μ', 'nu': 'ν', 'xi': 'ξ', 'Xi': 'Ξ',
    'pi': 'π', 'Pi': 'Π', 'rho': 'ρ', 'varrho': 'ϱ',
    'sigma': 'σ', 'Sigma': 'Σ', 'tau': 'τ', 'upsilon': 'υ', 'Upsilon': 'Υ',
    'phi': 'φ', 'varphi': 'ϕ', 'Phi': 'Φ', 'chi': 'χ',
    'psi': 'ψ', 'Psi': 'Ψ', 'omega': 'ω', 'Omega': 'Ω',
  };

  // ⚡ Comprehensive Mathematical Operators & Symbols Map
  static const Map<String, String> _operatorMap = {
    'times': '×', 'cdot': '·', 'bullet': '•', 'div': '÷',
    'pm': '±', 'mp': '∓',
    'leq': '≤', 'le': '≤', 'geq': '≥', 'ge': '≥',
    'neq': '≠', 'ne': '≠', 'approx': '≈', 'equiv': '≡',
    'propto': '∝', 'sim': '∼', 'infty': '∞', 'inf': '∞',
    'partial': '∂', 'nabla': '∇',
    'in': '∈', 'notin': '∉', 'subset': '⊂', 'subseteq': '⊆',
    'cup': '∪', 'cap': '∩', 'setminus': '\\',
    'forall': '∀', 'exists': '∃', 'nexists': '∄',
    'int': '∫', 'iint': '∬', 'iiint': '∭', 'oint': '∮',
    'sum': '∑', 'prod': '∏',
    'rightarrow': '→', 'to': '→', 'leftarrow': '←', 'gets': '←',
    'Rightarrow': '⇒', 'implies': '⇒', 'Leftarrow': '⇐',
    'leftrightarrow': '↔', 'Leftrightarrow': '⇔', 'iff': '⇔',
    'degree': '°', 'circ': '°',
    'therefore': '∴', 'because': '∵',
    'angle': '∠', 'perp': '⊥', 'parallel': '∥',
    'hbar': 'ℏ', 'ell': 'ℓ',
    'hat': '^', 'tilde': '~',
    'dag': '†', 'ddag': '‡',
  };

  // ⚡ Number Sets & Blackboard Bold
  static const Map<String, String> _bbMap = {
    'R': 'ℝ', 'N': 'ℕ', 'Z': 'ℤ', 'C': 'ℂ', 'Q': 'ℚ',
    'P': 'ℙ', 'H': 'ℍ', 'F': '𝔽',
  };

  // ⚡ Superscript & Subscript Unicode translation tables
  static const Map<String, String> _supMap = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
    '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
    'n': 'ⁿ', 'i': 'ⁱ', 'x': 'ˣ', 'y': 'ʸ', 't': 'ᵗ',
    'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ',
    'm': 'ᵐ', 'p': 'ᵖ', 'r': 'ʳ', 's': 'ˢ', 'k': 'ᵏ',
  };

  static const Map<String, String> _subMap = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
    'a': 'ₐ', 'e': 'ₑ', 'o': 'ₒ', 'x': 'ₓ', 'n': 'ₙ',
    'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ', 't': 'ₜ', 'p': 'ₚ',
    'r': 'ᵣ', 'u': 'ᵤ', 'v': 'ᵥ', 'm': 'ₘ', 's': 'ₛ',
  };

  // Compiled regexes for high-throughput string cleaning
  static final RegExp _macroWithArgRx = RegExp(r'\\[a-zA-Z]+(?:\[[^\]]*\])?\{([^{}]*)\}');
  static final RegExp _fracRx = RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}');
  static final RegExp _sqrtNthRx = RegExp(r'\\sqrt\[([^\]]*)\]\{([^{}]*)\}');
  static final RegExp _sqrtRx = RegExp(r'\\sqrt\{([^{}]*)\}');
  static final RegExp _vecRx = RegExp(r'\\vec\{([^{}]*)\}');
  static final RegExp _mathbbRx = RegExp(r'\\mathbb\{([A-Z])\}');
  static final RegExp _wordCommandRx = RegExp(r'\\([a-zA-Z]+)');
  static final RegExp _supBraceRx = RegExp(r'\^\{([^{}]+)\}');
  static final RegExp _supCharRx = RegExp(r'\^([0-9\+\-a-zA-Z])');
  static final RegExp _subBraceRx = RegExp(r'_\{([^{}]+)\}');
  static final RegExp _subCharRx = RegExp(r'_([0-9])');
  static final RegExp _escapedPunctuationRx = RegExp(r'\\([%&_\$#{}\\])');
  static final RegExp _spacesRx = RegExp(r'\s{2,}');

  /// Universal Sanitizer: cleans ANY text (prose, bullets, mind map cards, flashcards)
  /// Converts mathematical symbols to Unicode and UNIVERSALLY strips accidental backslashes from English words.
  static String clean(String raw) {
    if (raw.isEmpty || (!raw.contains(r'\') && !raw.contains('^') && !raw.contains(r'$'))) return raw;

    String s = raw;

    // 1. Temporarily protect escaped currency dollar signs (\$50 -> preserved $)
    const escDollarToken = '\uE000';
    s = s.replaceAll(r'\$', escDollarToken);

    // 2. Un-escape common LaTeX-escaped punctuation: \%, \&, \_, \#, \{, \}
    s = s.replaceAllMapped(_escapedPunctuationRx, (m) => m.group(1) ?? '');

    // 3. Remove LaTeX spacing commands: \quad, \qquad, \, , \; , \: , \!
    s = s.replaceAll(r'\qquad', '  ')
         .replaceAll(r'\quad', ' ')
         .replaceAll(r'\,', ' ')
         .replaceAll(r'\;', ' ')
         .replaceAll(r'\:', ' ')
         .replaceAll(r'\!', '')
         .replaceAll(r'\ ', ' ')
         .replaceAll(r'\left', '')
         .replaceAll(r'\right', '')
         .replaceAll(r'\displaystyle', '');

    // 4. Known compound structures: Fractions & Roots
    s = s.replaceAllMapped(_fracRx, (m) => '(${m.group(1)} / ${m.group(2)})');
    s = s.replaceAllMapped(_sqrtNthRx, (m) => '${m.group(1)}√(${m.group(2)})');
    s = s.replaceAllMapped(_sqrtRx, (m) => '√(${m.group(1)})');
    s = s.replaceAll(r'\sqrt', '√');

    // 5. Vectors and Blackboard Bold: \vec{v} -> v⃗, \mathbb{R} -> ℝ
    s = s.replaceAllMapped(_vecRx, (m) => '${m.group(1)}⃗');
    s = s.replaceAllMapped(_mathbbRx, (m) => _bbMap[m.group(1)] ?? m.group(1)!);

    // 6. Recursive unwrapping of ANY macro with braces: \text{...}, \textbf{...}, \example{...}, \custom{...}
    int unwrapLimit = 5;
    while (_macroWithArgRx.hasMatch(s) && unwrapLimit > 0) {
      s = s.replaceAllMapped(_macroWithArgRx, (m) => m.group(1) ?? '');
      unwrapLimit--;
    }

    // 7. ✨ UNIVERSAL BACKSLASH RESOLVER FOR ANY \word
    // If it's a known Greek symbol -> convert to Unicode symbol
    // If it's a known operator -> convert to Unicode operator
    // If it's ANY other word (e.g. \example, \cent, \center, \step, \log, \sin) -> UNIVERSALLY strip the backslash and keep the word!
    s = s.replaceAllMapped(_wordCommandRx, (m) {
      final word = m.group(1)!;

      // Check Greek symbols
      if (_greekMap.containsKey(word)) {
        return _greekMap[word]!;
      }
      // Check operators
      if (_operatorMap.containsKey(word)) {
        return _operatorMap[word]!;
      }
      // Specific common word overrides if any
      if (word == 'cent') return 'cent';
      if (word == 'example') return 'example';
      if (word == 'Example') return 'Example';

      // Universal Fallback: Strip backslash and preserve the clean natural word!
      return word;
    });

    // 8. Superscripts and Subscripts (e.g. x^2 -> x², CO_2 -> CO₂)
    s = s.replaceAllMapped(_supBraceRx, (m) {
      final content = m.group(1) ?? '';
      return content.split('').map((c) => _supMap[c] ?? c).join();
    });
    s = s.replaceAllMapped(_supCharRx, (m) => _supMap[m.group(1)] ?? m.group(0)!);

    s = s.replaceAllMapped(_subBraceRx, (m) {
      final content = m.group(1) ?? '';
      return content.split('').map((c) => _subMap[c] ?? c).join();
    });
    s = s.replaceAllMapped(_subCharRx, (m) => _subMap[m.group(1)] ?? m.group(0)!);

    // 9. Clean trailing dangling math delimiters if left in plain text: \( \) \[ \] $$ $ and stray backslashes
    s = s.replaceAll(r'\(', '')
         .replaceAll(r'\)', '')
         .replaceAll(r'\[', '')
         .replaceAll(r'\]', '')
         .replaceAll(r'$$', '')
         .replaceAll(r'$', '')
         .replaceAll(r'\', '');

    // 10. Restore protected currency dollar sign
    s = s.replaceAll(escDollarToken, r'$');

    // 11. Normalize duplicate spaces
    s = s.replaceAll(_spacesRx, ' ').trim();

    return s;
  }

  /// Specialized math expression cleaner for KaTeX fallback mode
  static String cleanMathFallback(String rawMath) {
    var s = rawMath.trim();
    if (s.startsWith(r'$$') && s.endsWith(r'$$') && s.length >= 4) {
      s = s.substring(2, s.length - 2).trim();
    } else if (s.startsWith(r'$') && s.endsWith(r'$') && s.length >= 2) {
      s = s.substring(1, s.length - 1).trim();
    } else if (s.startsWith(r'\(') && s.endsWith(r'\)') && s.length >= 4) {
      s = s.substring(2, s.length - 2).trim();
    }
    return clean(s);
  }
}
