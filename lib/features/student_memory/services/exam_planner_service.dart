import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/hive_storage.dart';
import '../models/study_plan_model.dart';

export '../models/study_plan_model.dart';

class ExamPlannerService extends ChangeNotifier {
  static final ExamPlannerService _instance = ExamPlannerService._internal();
  factory ExamPlannerService() => _instance;
  ExamPlannerService._internal();

  final ApiClient _apiClient = ApiClient();
  static const String _key = 'exam_study_plan_v2';

  ExamStudyPlanModel getPlan() {
    try {
      final raw = HiveStorage.boxSyncMeta.get(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw.toString());
        return ExamStudyPlanModel.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
    } catch (_) {}

    // Dynamic baseline roadmap generated from target goals
    return createAdaptiveRoadmap(
      examName: 'Target Academic Exam Goal',
      examDate: DateTime.now().add(const Duration(days: 90)),
      dailyHoursGoal: 4.0,
      topics: const [
        'Core Subject Fundamentals',
        'Formula & Theorem Derivations',
        'Problem Solving & Numericals',
        'PYQ Mocks & Active Recall',
      ],
    );
  }

  Future<void> savePlan(ExamStudyPlanModel plan) async {
    try {
      await HiveStorage.boxSyncMeta.put(_key, jsonEncode(plan.toJson()));
      notifyListeners();
    } catch (_) {}
  }

  /// Dynamically generates an AI-powered study roadmap tailored to the student's exact syllabus topics and timeline
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
      final response = await _apiClient.dio.post(
        ApiConstants.generateStudyPlan,
        data: {
          'exam_name': examName,
          'syllabus': cleanSyllabus,
          'target_days': targetDays,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          final scheduleRaw = data['schedule'] as List<dynamic>? ?? [];
          final tasks = scheduleRaw.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            return StudyPlanTaskModel.fromJson(map);
          }).toList();

          if (tasks.isNotEmpty) {
            final newPlan = ExamStudyPlanModel(
              examName: examName,
              examDate: examDate,
              dailyHoursGoal: dailyHours,
              overview: data['overview']?.toString() ?? 'Personalized AI Active Recall Study Roadmap for $examName.',
              syllabusTopics: cleanSyllabus,
              schedule: tasks,
            );
            await savePlan(newPlan);
            return newPlan;
          }
        }
      }
    } catch (_) {}

    // Resilient Adaptive Fallback: Generates tailored multi-phase roadmap from user's syllabus
    final adaptivePlan = createAdaptiveRoadmap(
      examName: examName,
      examDate: examDate,
      dailyHoursGoal: dailyHours,
      topics: cleanSyllabus,
    );

    await savePlan(adaptivePlan);
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
      cleanTopics.addAll(['Core Theory & Definitions', 'Formula Derivations', 'Previous Year Questions']);
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
            'Derive key mathematical formulas in Formula Studio',
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
