import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/routes/app_router.dart';
import '../models/study_engine_model.dart';

/// Riverpod 3.x Notifier for Dashboard Search Query
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String val) => state = val;
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// Riverpod 3.x Notifier for Study Engine Category Filter
class EngineCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setCategory(String category) => state = category;
}

final engineCategoryProvider = NotifierProvider<EngineCategoryNotifier, String>(EngineCategoryNotifier.new);

/// Provider holding the 6 core AI Study Engines (clean, typed, and uncluttered)
final studyEnginesProvider = Provider<List<StudyEngineItem>>((ref) {
  return const [
    StudyEngineItem(
      id: 'socratic_tutor',
      title: 'Socratic Tutor',
      description: 'Step-by-step doubt reasoning & concept breakdown.',
      icon: Icons.psychology_outlined,
      route: AppRoutes.aiChat,
      badge: 'Deep AI',
      category: 'theory',
    ),
    StudyEngineItem(
      id: 'adaptive_quizzes',
      title: 'Adaptive Quizzes',
      description: 'Diagnostic recall tests targeted at your weak spots.',
      icon: Icons.quiz_outlined,
      route: AppRoutes.quizzes,
      badge: 'Diagnostic',
      category: 'practice',
    ),
    StudyEngineItem(
      id: 'concept_mind_maps',
      title: 'Concept Mind Maps',
      description: 'Interactive visual hierarchy & knowledge trees.',
      icon: Icons.account_tree_outlined,
      route: AppRoutes.diagram,
      badge: 'Visual Tree',
      category: 'theory',
    ),
    StudyEngineItem(
      id: 'formula_studio',
      title: 'Formula Studio',
      description: 'Formulas, equation solvers & KaTeX derivations.',
      icon: Icons.functions_outlined,
      route: AppRoutes.formulaStudio,
      badge: 'KaTeX Solver',
      category: 'tools',
    ),
    StudyEngineItem(
      id: 'flip_flashcards',
      title: '3D Flip Flashcards',
      description: 'Spaced repetition cards for long-term memory.',
      icon: Icons.style_outlined,
      route: 'sheet:flashcards',
      badge: 'Spaced Recall',
      category: 'practice',
    ),
    StudyEngineItem(
      id: 'study_planner',
      title: 'Exam Study Planner',
      description: 'Syllabus roadmap with integrated Pomodoro timer.',
      icon: Icons.calendar_today_outlined,
      route: 'sheet:planner',
      badge: 'Roadmap',
      category: 'tools',
    ),
  ];
});

/// Provider returning study engines filtered by active category
final filteredStudyEnginesProvider = Provider<List<StudyEngineItem>>((ref) {
  final category = ref.watch(engineCategoryProvider);
  final all = ref.watch(studyEnginesProvider);
  if (category == 'all') return all;
  return all.where((e) => e.category == category).toList();
});
