import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/hive_storage.dart';
import '../models/study_plan_model.dart';
import 'study_plan_repository.dart';

export '../models/study_plan_model.dart';

class ExamPlannerService extends ChangeNotifier {
  static final ExamPlannerService _instance = ExamPlannerService._internal();
  factory ExamPlannerService() => _instance;
  ExamPlannerService._internal();

  final ApiClient _apiClient = ApiClient();
  final StudyPlanRepository _repository = StudyPlanRepository();
  static const String _key = 'exam_study_plan_v2';

  /// Synchronously loads cached study plan from Hive local storage
  ExamStudyPlanModel getPlan() {
    try {
      final raw = HiveStorage.boxSyncMeta.get(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw.toString());
        return ExamStudyPlanModel.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
    } catch (_) {}

    // Clean baseline without any hardcoded goals/tasks
    return ExamStudyPlanModel(
      examName: 'Target Academic Exam',
      examDate: DateTime.now().add(const Duration(days: 90)),
      dailyHoursGoal: 4.0,
      overview: 'Personalized AI Active Recall Study Roadmap.',
      syllabusTopics: const [],
      schedule: const [],
    );
  }

  /// Fetches the user's study roadmap from the backend API, updating local Hive cache.
  /// Falls back to local cache if offline or backend is unreachable.
  Future<ExamStudyPlanModel> fetchPlan() async {
    try {
      final roadmaps = await _repository.listRoadmaps();
      if (roadmaps.isNotEmpty) {
        // Get the active or latest saved backend roadmap
        final latest = roadmaps.firstWhere((r) => r.isActive,orElse: () => roadmaps.first);
        final localCache = getPlan();
        final backendPlan = latest.toExamStudyPlan().copyWith(
          dailyHoursGoal: localCache.dailyHoursGoal,
          totalStudyMinutes: localCache.totalStudyMinutes,
        );

        await _saveToLocalCache(backendPlan);
        notifyListeners();
        return backendPlan;
      }
    } catch (_) {}

    return getPlan();
  }

  /// Internal helper to persist plan to local Hive cache
  Future<void> _saveToLocalCache(ExamStudyPlanModel plan) async {
    try {
      await HiveStorage.boxSyncMeta.put(_key, jsonEncode(plan.toJson()));
    } catch (_) {}
  }

  /// Saves study plan to local Hive storage AND syncs to Backend DB (POST/PATCH)
  Future<void> savePlan(ExamStudyPlanModel plan) async {
    await _saveToLocalCache(plan);
    notifyListeners();

    // Async sync with Backend Database
    try {
      if (plan.id != null && plan.id!.isNotEmpty && !plan.id!.startsWith('local-')) {
        // Update existing backend roadmap
        await _repository.updateRoadmap(
          plan.id!,
          UpdateRoadmapRequest(
            examName: plan.examName,
            overview: plan.overview,
            schedule: plan.schedule,
          ),
        );
      } else {
        // Create new roadmap on backend DB
        final saved = await _repository.saveRoadmap(
          SaveRoadmapRequest(
            examName: plan.examName,
            overview: plan.overview,
            syllabus: plan.syllabusTopics,
            targetDays: plan.daysRemaining,
            schedule: plan.schedule,
          ),
        );

        if (saved != null && saved.id.isNotEmpty) {
          final updatedWithId = plan.copyWith(id: saved.id);
          await _saveToLocalCache(updatedWithId);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Dynamically generates an AI-powered study roadmap, persists it on backend DB & local cache
  Future<ExamStudyPlanModel> generateAiPlan({
    required String examName,
    required DateTime examDate,
    required List<String> syllabus,
    required double dailyHours,
    String? focusStyle,
  }) async {
    final now = DateTime.now();
    final days = examDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    final targetDays = days > 0 ? days.clamp(7, 365) : 30;

    final cleanSyllabus = syllabus.where((s) => s.trim().isNotEmpty).toList();
    if (cleanSyllabus.isEmpty) {
      cleanSyllabus.addAll(['Core Theory & Definitions', 'Formula Derivations', 'Previous Year Questions']);
    }

    try {
      final response = await _repository.generateAIRoadmap(
        examName: examName,
        syllabus: cleanSyllabus,
        targetDays: targetDays,
        saveToDB: true,
      );

      if (response != null && response.schedule.isNotEmpty) {
        String? roadmapId = response.roadmapId;

        // If backend did not return a roadmapId, explicitly save to DB
        if (roadmapId == null || roadmapId.isEmpty) {
          final savedRoadmap = await _repository.saveRoadmap(
            SaveRoadmapRequest(
              examName: examName,
              overview: response.overview,
              syllabus: cleanSyllabus,
              targetDays: targetDays,
              schedule: response.schedule,
            ),
          );
          roadmapId = savedRoadmap?.id;
        }

        final newPlan = ExamStudyPlanModel(
          id: roadmapId,
          examName: examName,
          examDate: examDate,
          dailyHoursGoal: dailyHours,
          overview: response.overview.isNotEmpty
              ? response.overview
              : 'Personalized AI Active Recall Study Roadmap for $examName.',
          syllabusTopics: cleanSyllabus,
          schedule: response.schedule,
        );

        await _saveToLocalCache(newPlan);
        notifyListeners();
        return newPlan;
      }
    } catch (_) {}

    // Resilient Adaptive Fallback: Generates tailored multi-phase roadmap from syllabus
    final adaptivePlan = createAdaptiveRoadmap(
      examName: examName,
      examDate: examDate,
      dailyHoursGoal: dailyHours,
      topics: cleanSyllabus,
    );

    // Persist fallback adaptive plan to backend DB
    try {
      final saved = await _repository.saveRoadmap(
        SaveRoadmapRequest(
          examName: adaptivePlan.examName,
          overview: adaptivePlan.overview,
          syllabus: adaptivePlan.syllabusTopics,
          targetDays: targetDays,
          schedule: adaptivePlan.schedule,
        ),
      );
      if (saved != null && saved.id.isNotEmpty) {
        final planWithId = adaptivePlan.copyWith(id: saved.id);
        await _saveToLocalCache(planWithId);
        notifyListeners();
        return planWithId;
      }
    } catch (_) {}

    await _saveToLocalCache(adaptivePlan);
    notifyListeners();
    return adaptivePlan;
  }

  /// Generates a structured multi-phase adaptive roadmap from syllabus topics
  static ExamStudyPlanModel createAdaptiveRoadmap({
    required String examName,
    required DateTime examDate,
    required double dailyHoursGoal,
    required List<String> topics,
  }) {
    final cleanTopics = topics.where((s) => s.trim().isNotEmpty).toList();
    if (cleanTopics.isEmpty) {
      return ExamStudyPlanModel(
        examName: examName,
        examDate: examDate,
        dailyHoursGoal: dailyHoursGoal,
        overview: 'Personalized AI Active Recall Study Roadmap for $examName.',
        syllabusTopics: const [],
        schedule: const [],
      );
    }

    final targetDays = examDate.difference(DateTime.now()).inDays.clamp(3, 90);
    final generatedTasks = <StudyPlanTaskModel>[];

    for (int i = 0; i < cleanTopics.length; i++) {
      final topic = cleanTopics[i];
      final dayNum = (i * 2) + 1;

      generatedTasks.add(
        StudyPlanTaskModel(
          id: 'ai-task-${DateTime.now().microsecondsSinceEpoch}-$i-a',
          dayNumber: dayNum,
          title: '$topic: Deep Concept & Derivation Mastery',
          focusArea: 'Theory & Derivation',
          priority: i == 0 ? 'high' : 'medium',
          subtasks: [
            'Study core principles and governing equations for $topic',
            'Review key conceptual formulas and active recall principles',
            'Create active recall flashcard deck for definition mastery',
          ],
        ),
      );

      generatedTasks.add(
        StudyPlanTaskModel(
          id: 'ai-task-${DateTime.now().microsecondsSinceEpoch}-$i-b',
          dayNumber: dayNum + 1,
          title: '$topic: PYQ Drills & Examiner Trap Forensics',
          focusArea: 'Practice & PYQ Mocks',
          priority: 'high',
          subtasks: [
            'Solve 10 previous year questions on $topic',
            'Identify and document tricky examiner traps and sign errors',
            'Test understanding with a 5-question Adaptive Quiz',
          ],
        ),
      );
    }

    // Final Spaced Repetition Mock Phase
    generatedTasks.add(
      StudyPlanTaskModel(
        id: 'ai-task-final-review',
        dayNumber: targetDays,
        title: 'Full-Length Timed Mock & Weak Area Diagnostic',
        focusArea: 'Full Mock & Final Lock',
        priority: 'high',
        subtasks: const [
          'Complete 1 full-length timed mock test under exam conditions',
          'Review incorrect answers with Socratic AI Tutor',
          'Final high-yield formula review before exam day',
        ],
      ),
    );

    return ExamStudyPlanModel(
      examName: examName,
      examDate: examDate,
      dailyHoursGoal: dailyHoursGoal,
      overview: 'AI-generated active recall and spaced repetition roadmap designed for $examName over $targetDays days.',
      syllabusTopics: cleanTopics,
      schedule: generatedTasks,
    );
  }

  /// Toggles task completion state
  Future<void> toggleTask(String taskId, bool isCompleted) async {
    final current = getPlan();
    final updatedSchedule = current.schedule.map((task) {
      if (task.id == taskId) {
        task.isCompleted = isCompleted;
      }
      return task;
    }).toList();

    final updated = current.copyWith(schedule: updatedSchedule);
    await savePlan(updated);
  }

  /// Adds a custom study task to the roadmap
  Future<void> addTask(StudyPlanTaskModel task) async {
    final current = getPlan();
    final updatedSchedule = List<StudyPlanTaskModel>.from(current.schedule)..add(task);
    // Sort tasks by day number
    updatedSchedule.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    final updated = current.copyWith(schedule: updatedSchedule);
    await savePlan(updated);
  }

  /// Deletes a task from the roadmap
  Future<void> deleteTask(String taskId) async {
    final current = getPlan();
    final updatedSchedule = current.schedule.where((t) => t.id != taskId).toList();
    final updated = current.copyWith(schedule: updatedSchedule);
    await savePlan(updated);
  }

  /// Records focused study minutes to backend and local stats
  Future<void> recordFocusMinutes(int minutes) async {
    if (minutes <= 0) return;
    final current = getPlan();
    final updated = current.copyWith(
      totalStudyMinutes: current.totalStudyMinutes + minutes,
    );
    await savePlan(updated);

    try {
      await _apiClient.dio.post(
        ApiConstants.recordStudyTime,
        data: {'minutes': minutes},
      );
    } catch (_) {}
  }
}
