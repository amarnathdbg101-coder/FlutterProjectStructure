import 'package:flutter/material.dart';
import '../models/student_memory.dart';

/// Represents a dynamic, context-aware prompt suggestion for AI interactions.
class SmartPromptItem {
  final String label;
  final String prompt;
  final IconData icon;

  const SmartPromptItem({
    required this.label,
    required this.prompt,
    this.icon = Icons.psychology_outlined,
  });
}

/// Smart AI Context Helper
/// 
/// Replaces static, hardcoded questions, hints, and suggestions across the app.
/// Dynamically tailors prompts, question suggestions, and hints based on:
/// 1. Student's actual Weak Topics (highest priority for active recall)
/// 2. Student's Target Exam & Academic Domain (GATE CS, NEET, JEE, CBSE Boards, UPSC, etc.)
/// 3. Currently selected AI Tutor Mode (Socratic, Feynman, Exam Cram, Derivations, etc.)
class SmartAiContextHelper {
  // --- Exam Domain Profiles ---

  static const List<String> _csTopics = [
    'Data Structures & Algorithms',
    'Operating Systems & Concurrency',
    'Computer Networks & Protocols',
    'Database Management & Indexing',
    'Computer Architecture & Pipelining',
    'Theory of Computation & Automata',
  ];

  static const List<String> _medicalTopics = [
    'Molecular Basis of Inheritance',
    'Human Physiology & Circulation',
    'Genetics & Mendelian Principles',
    'Organic Reaction Mechanisms',
    'Chemical Equilibrium & Thermodynamics',
    'Cell Structure & Division',
  ];

  static const List<String> _engineeringTopics = [
    'Rotational Dynamics & Inertia',
    'Electromagnetic Induction & Optics',
    'Definite Integrals & Calculus',
    'Thermodynamics & Heat Cycles',
    'Matrices & Linear Transformations',
    'Chemical Kinetics & Equilibrium',
  ];

  static const List<String> _schoolTopics = [
    'Electricity & Ohm\'s Law',
    'Light: Reflection & Refraction',
    'Carbon & Its Chemical Compounds',
    'Life Processes & Circulation',
    'Quadratic Equations & Trigonometry',
    'Acids, Bases & Salts',
  ];

  static const List<String> _civilServicesTopics = [
    'Indian Constitutional Framework & Rights',
    'Monsoon Dynamics & Physical Geography',
    'Macroeconomics, Inflation & Monetary Policy',
    'Modern Indian Freedom Movement',
    'International Relations & Multilateral Treaties',
    'Environmental Ecology & Biodiversity',
  ];

  static const List<String> _generalTopics = [
    'Active Recall & Spaced Repetition',
    'Critical Thinking & Logic Proofs',
    'Scientific Method & Data Analysis',
    'Core Mathematical Foundations',
    'Thermodynamics Principles',
    'Probability & Applied Statistics',
  ];

  /// Resolves the appropriate syllabus topics based on the student's target exam.
  static List<String> getExamTopics(String? targetExam) {
    if (targetExam == null || targetExam.trim().isEmpty) {
      return _generalTopics;
    }
    final lower = targetExam.toLowerCase();

    if (lower.contains('gate') ||
        lower.contains('computer') ||
        lower.contains('tech') ||
        lower.contains('code') ||
        lower.contains('coding') ||
        lower.contains('software')) {
      return _csTopics;
    }

    if (lower.contains('neet') ||
        lower.contains('medical') ||
        lower.contains('biology') ||
        lower.contains('mbbs') ||
        lower.contains('doctor') ||
        lower.contains('usmle')) {
      return _medicalTopics;
    }

    if (lower.contains('jee') ||
        lower.contains('iit') ||
        lower.contains('bitsat') ||
        lower.contains('engineering') ||
        lower.contains('physics') ||
        lower.contains('math')) {
      return _engineeringTopics;
    }

    if (lower.contains('class 10') ||
        lower.contains('class 12') ||
        lower.contains('cbse') ||
        lower.contains('icse') ||
        lower.contains('board') ||
        lower.contains('school')) {
      return _schoolTopics;
    }

    if (lower.contains('upsc') ||
        lower.contains('civil') ||
        lower.contains('ias') ||
        lower.contains('ips') ||
        lower.contains('humanities') ||
        lower.contains('history') ||
        lower.contains('polity')) {
      return _civilServicesTopics;
    }

    return _generalTopics;
  }

  /// Returns 4 dynamic quick prompt chips for the Dashboard.
  /// If student has weak topics, they are directly featured as high-priority revision chips.
  /// Otherwise, curriculum-specific chips for their target exam are generated.
  static List<SmartPromptItem> getDashboardQuickChips(StudentMemoryProfile? profile) {
    final weak = profile?.weakTopics ?? [];
    final exam = profile?.targetExam ?? 'Academic Studies';
    final examTopics = getExamTopics(profile?.targetExam);

    final List<SmartPromptItem> items = [];

    // Priority 1: User's actual weak topics
    for (int i = 0; i < weak.length && items.length < 4; i++) {
      final topic = weak[i];
      if (i == 0) {
        items.add(SmartPromptItem(
          label: '🎯 $topic Traps',
          prompt: 'What are the most common exam traps, sign errors, and misconceptions in $topic for $exam?',
          icon: Icons.track_changes_rounded,
        ));
      } else if (i == 1) {
        items.add(SmartPromptItem(
          label: '💡 Intuition: $topic',
          prompt: 'Explain the core intuition and practical mental model of $topic without confusing jargon.',
          icon: Icons.lightbulb_outline_rounded,
        ));
      } else if (i == 2) {
        items.add(SmartPromptItem(
          label: '📐 $topic Formulas',
          prompt: 'Provide a structured summary of essential formulas and derivations for $topic.',
          icon: Icons.functions_rounded,
        ));
      } else {
        items.add(SmartPromptItem(
          label: '⚡ Drill: $topic',
          prompt: 'Give me 3 conceptual practice questions with step-by-step solutions for $topic.',
          icon: Icons.bolt_rounded,
        ));
      }
    }

    // Priority 2: Complement with exam-specific high-yield topics if weak topics < 4
    int topicIdx = 0;
    while (items.length < 4 && topicIdx < examTopics.length) {
      final topic = examTopics[topicIdx];
      // Avoid duplicates
      if (!weak.contains(topic)) {
        if (items.isEmpty) {
          items.add(SmartPromptItem(
            label: '⚡ $topic Overview',
            prompt: 'Explain the fundamental concepts and key theorems of $topic for $exam.',
            icon: Icons.bolt_rounded,
          ));
        } else if (items.length == 1) {
          items.add(SmartPromptItem(
            label: '📐 $topic Derivation',
            prompt: 'Step-by-step breakdown and mathematical formulation for $topic.',
            icon: Icons.functions_rounded,
          ));
        } else if (items.length == 2) {
          items.add(SmartPromptItem(
            label: '🎯 $topic Pitfalls',
            prompt: 'What are the top 3 high-yield problem-solving traps in $topic?',
            icon: Icons.track_changes_rounded,
          ));
        } else {
          items.add(SmartPromptItem(
            label: '💡 $topic Analogy',
            prompt: 'Explain $topic using a clear, real-world intuitive analogy.',
            icon: Icons.lightbulb_outline_rounded,
          ));
        }
      }
      topicIdx++;
    }

    return items;
  }

  /// Returns smart prompt suggestions for the AI Tutor Chat screen (empty state).
  /// Tailors suggestions to the currently active Tutor Mode (Socratic, Feynman, Exam Cram, etc.)
  /// and the student's actual cognitive profile.
  static List<SmartPromptItem> getSmartTutorSuggestions({
    StudentMemoryProfile? profile,
    String? tutorModeKey,
  }) {
    final weak = profile?.weakTopics ?? [];
    final exam = profile?.targetExam ?? 'Exam Preparation';
    final examTopics = getExamTopics(profile?.targetExam);

    // Pick top focus topic
    final primaryTopic = weak.isNotEmpty ? weak.first : examTopics.first;
    final secondaryTopic = weak.length > 1
        ? weak[1]
        : (examTopics.length > 1 ? examTopics[1] : 'Fundamental Laws');
    final tertiaryTopic = weak.length > 2
        ? weak[2]
        : (examTopics.length > 2 ? examTopics[2] : 'Problem Solving Traps');

    final mode = (tutorModeKey ?? 'socratic').toLowerCase();

    if (mode.contains('feynman')) {
      return [
        SmartPromptItem(
          label: '💡 Feynman: $primaryTopic',
          prompt: 'Explain $primaryTopic like I am 12 years old using simple everyday analogies and zero technical jargon.',
          icon: Icons.lightbulb_outline_rounded,
        ),
        SmartPromptItem(
          label: '🔍 Everyday Analogy: $secondaryTopic',
          prompt: 'What is a real-world physical analogy to understand the core mechanism of $secondaryTopic?',
          icon: Icons.compare_arrows_rounded,
        ),
        SmartPromptItem(
          label: '❓ Test My Intuition: $primaryTopic',
          prompt: 'Ask me a simple intuitive question to test if I truly understand $primaryTopic without formulas.',
          icon: Icons.help_outline_rounded,
        ),
        SmartPromptItem(
          label: '🔄 Simplify Complex Concept: $tertiaryTopic',
          prompt: 'Break down $tertiaryTopic into 3 simple, non-intimidating building blocks.',
          icon: Icons.layers_outlined,
        ),
      ];
    }

    if (mode.contains('cram') || mode.contains('exam') || mode.contains('pyq') || mode.contains('trap')) {
      return [
        SmartPromptItem(
          label: '🎯 High-Yield Traps: $primaryTopic',
          prompt: 'What are the top 5 highest frequency exam traps and tricky questions in $primaryTopic for $exam?',
          icon: Icons.warning_amber_rounded,
        ),
        SmartPromptItem(
          label: '⏱️ 5-Minute PYQ Summary: $secondaryTopic',
          prompt: 'Give me a rapid 5-minute revision sheet for $secondaryTopic with must-know formulas and PYQ shortcuts.',
          icon: Icons.timer_outlined,
        ),
        SmartPromptItem(
          label: '⚡ Scoring Formula Cheat Sheet: $primaryTopic',
          prompt: 'List the high-probability formula sheet for $primaryTopic with common sign conventions and SI units.',
          icon: Icons.table_chart_outlined,
        ),
        SmartPromptItem(
          label: '📊 Elimination Strategy: $tertiaryTopic',
          prompt: 'How to quickly eliminate wrong options in multi-choice questions on $tertiaryTopic?',
          icon: Icons.checklist_rounded,
        ),
      ];
    }

    if (mode.contains('deriv') || mode.contains('math') || mode.contains('formula')) {
      return [
        SmartPromptItem(
          label: '📐 Rigorous Derivation: $primaryTopic',
          prompt: 'Provide complete step-by-step LaTeX derivation of the governing equations for $primaryTopic.',
          icon: Icons.functions_rounded,
        ),
        SmartPromptItem(
          label: '🔬 Physical Meaning of Variables: $secondaryTopic',
          prompt: 'In $secondaryTopic, explain the physical and dimensional significance of each variable in the formula.',
          icon: Icons.science_outlined,
        ),
        SmartPromptItem(
          label: '⚠️ Boundary Conditions: $primaryTopic',
          prompt: 'What are the critical assumptions and boundary conditions where the standard formulas for $primaryTopic break down?',
          icon: Icons.rule_rounded,
        ),
        SmartPromptItem(
          label: '📈 Graphical Interpretation: $tertiaryTopic',
          prompt: 'How do the curves and slope/area properties behave in $tertiaryTopic graphs?',
          icon: Icons.show_chart_rounded,
        ),
      ];
    }

    // Default Socratic Mode (interactive reasoning)
    return [
      SmartPromptItem(
        label: '🧠 Socratic Inquiry: $primaryTopic',
        prompt: 'Guide me through understanding $primaryTopic step-by-step using probing questions so I can deduce the laws myself.',
        icon: Icons.psychology_outlined,
      ),
      SmartPromptItem(
        label: '🎯 Common Traps: $secondaryTopic',
        prompt: 'What common logical fallacies or sign errors do students make when solving $secondaryTopic in $exam?',
        icon: Icons.track_changes_rounded,
      ),
      SmartPromptItem(
        label: '⚖️ Comparative Matrix: $primaryTopic vs $secondaryTopic',
        prompt: 'Compare and contrast the core principles of $primaryTopic and $secondaryTopic in a clear matrix table.',
        icon: Icons.table_rows_rounded,
      ),
      SmartPromptItem(
        label: '💡 Core Intuition: $tertiaryTopic',
        prompt: 'Explain the fundamental intuition behind $tertiaryTopic with a concrete practical example.',
        icon: Icons.lightbulb_outline_rounded,
      ),
    ];
  }

  /// Returns dynamic suggested topics for Quizzes and Mind Map generation dialogs.
  /// Blends the student's actual weak topics with exam curriculum topics.
  static List<String> getSuggestedTopics(StudentMemoryProfile? profile) {
    return getSuggestedTopicsFromParams(
      weakTopics: profile?.weakTopics ?? [],
      targetExam: profile?.targetExam,
    );
  }

  /// Returns dynamic suggested topics given raw weakTopics and targetExam strings.
  static List<String> getSuggestedTopicsFromParams({
    List<String> weakTopics = const [],
    String? targetExam,
  }) {
    final examTopics = getExamTopics(targetExam);
    final List<String> list = [];

    // Add weak topics first
    for (final w in weakTopics) {
      if (!list.contains(w)) list.add(w);
    }

    // Fill with exam-tailored topics
    for (final t in examTopics) {
      if (!list.contains(t) && list.length < 8) {
        list.add(t);
      }
    }

    return list.isNotEmpty ? list : _generalTopics;
  }

  /// Returns a dynamic hint string for search and doubt inputs.
  static String getSmartInputHint(StudentMemoryProfile? profile, {String? defaultHint}) {
    if (profile?.weakTopics != null && profile!.weakTopics.isNotEmpty) {
      return 'Ask about ${profile.weakTopics.first} or any doubt...';
    }
    if (profile?.targetExam != null && profile!.targetExam.isNotEmpty) {
      return 'Ask any ${profile.targetExam} concept, formula, or trap...';
    }
    return defaultHint ?? 'Ask any academic question, formula, or exam trap...';
  }

  /// Returns a dynamic hint for topic input fields.
  static String getSmartTopicHint(StudentMemoryProfile? profile) {
    final topics = getSuggestedTopics(profile);
    if (topics.length >= 3) {
      return 'e.g. ${topics[0]}, ${topics[1]}, ${topics[2]}...';
    }
    return 'e.g. ${topics.join(', ')}...';
  }

  /// Returns the top priority weak topic, or an exam-appropriate fallback.
  static String getPriorityFocusTopic(StudentMemoryProfile? profile) {
    if (profile?.weakTopics != null && profile!.weakTopics.isNotEmpty) {
      return profile.weakTopics.first;
    }
    final examTopics = getExamTopics(profile?.targetExam);
    return examTopics.isNotEmpty ? examTopics.first : 'Active Recall & Spaced Repetition';
  }
}
