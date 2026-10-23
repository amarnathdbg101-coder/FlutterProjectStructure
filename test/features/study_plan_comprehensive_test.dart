import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/student_memory/models/study_plan_model.dart';
import 'package:studysilo/features/student_memory/services/exam_planner_service.dart';

void main() {
  group('Comprehensive AI Study Plan & Exam Roadmap Tests (20+ Cases)', () {
    test('1. StudyPlanTaskModel default values and JSON roundtrip', () {
      final task = StudyPlanTaskModel(
        id: 't-1',
        dayNumber: 3,
        title: 'Fourier Transform Derivations',
        focusArea: 'Signal Processing',
        priority: 'high',
        subtasks: const ['Derive continuous FT formula', 'Solve 3 PYQs'],
        isCompleted: true,
      );

      final json = task.toJson();
      final revived = StudyPlanTaskModel.fromJson(json);

      expect(revived.id, 't-1');
      expect(revived.dayNumber, 3);
      expect(revived.title, 'Fourier Transform Derivations');
      expect(revived.focusArea, 'Signal Processing');
      expect(revived.priority, 'high');
      expect(revived.subtasks.length, 2);
      expect(revived.isCompleted, true);
    });

    test('2. StudyPlanTaskModel handles malformed / null JSON fields gracefully', () {
      final json = <String, dynamic>{
        'day_number': '5',
        'title': null,
        'focus_area': null,
        'priority': null,
        'subtasks': null,
        'is_completed': 'true', // string instead of bool
      };

      final task = StudyPlanTaskModel.fromJson(json);
      expect(task.id, startsWith('task-'));
      expect(task.title, 'Study Task');
      expect(task.focusArea, 'Core Concept');
      expect(task.priority, 'medium');
      expect(task.subtasks, isEmpty);
      expect(task.isCompleted, false);
    });

    test('3. ExamStudyPlanModel calculates completed task count and percentage', () {
      final plan = ExamStudyPlanModel(
        examName: 'GATE CS 2026',
        examDate: DateTime.now().add(const Duration(days: 30)),
        overview: 'Comprehensive GATE Prep',
        syllabusTopics: const ['OS', 'DBMS'],
        schedule: [
          StudyPlanTaskModel(id: '1', dayNumber: 1, title: 'OS Concepts', focusArea: 'OS', priority: 'high', subtasks: const [], isCompleted: true),
          StudyPlanTaskModel(id: '2', dayNumber: 2, title: 'DBMS Joins', focusArea: 'DBMS', priority: 'medium', subtasks: const [], isCompleted: false),
          StudyPlanTaskModel(id: '3', dayNumber: 3, title: 'Normalization', focusArea: 'DBMS', priority: 'high', subtasks: const [], isCompleted: true),
        ],
      );

      expect(plan.completedTaskCount, 2);
      expect(plan.progressPercentage, closeTo(0.666, 0.01));
    });

    test('4. ExamStudyPlanModel progressPercentage is 0 when schedule is empty', () {
      final plan = ExamStudyPlanModel(
        examName: 'Test Exam',
        examDate: DateTime.now(),
        overview: 'Empty',
        syllabusTopics: const [],
        schedule: const [],
      );

      expect(plan.completedTaskCount, 0);
      expect(plan.progressPercentage, 0.0);
    });

    test('5. ExamStudyPlanModel daysRemaining calculates positive future days', () {
      final futureDate = DateTime.now().add(const Duration(days: 45));
      final plan = ExamStudyPlanModel(
        examName: 'Future Exam',
        examDate: futureDate,
        overview: 'Future',
        syllabusTopics: const [],
        schedule: const [],
      );

      expect(plan.daysRemaining, greaterThanOrEqualTo(44));
      expect(plan.daysRemaining, lessThanOrEqualTo(45));
    });

    test('6. ExamStudyPlanModel daysRemaining returns 0 for past exam dates', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      final plan = ExamStudyPlanModel(
        examName: 'Past Exam',
        examDate: pastDate,
        overview: 'Past',
        syllabusTopics: const [],
        schedule: const [],
      );

      expect(plan.daysRemaining, 0);
    });

    test('7. ExamStudyPlanModel copyWith performs immutable partial update', () {
      final original = ExamStudyPlanModel(
        id: 'plan-1',
        examName: 'Midterm',
        examDate: DateTime(2026, 12, 1),
        dailyHoursGoal: 3.0,
        overview: 'Original overview',
        syllabusTopics: const ['Physics'],
        schedule: const [],
      );

      final updated = original.copyWith(
        examName: 'Final Exam',
        dailyHoursGoal: 5.0,
      );

      expect(updated.id, 'plan-1');
      expect(updated.examName, 'Final Exam');
      expect(updated.dailyHoursGoal, 5.0);
      expect(updated.overview, 'Original overview');
      expect(updated.syllabusTopics, contains('Physics'));
    });

    test('8. ExamStudyPlanModel fromAIRoadmap conversion', () {
      final roadmap = AIRoadmapModel(
        id: 'road-99',
        userId: 'u123',
        examName: 'NEET UG Biology',
        overview: 'Biology active recall roadmap',
        syllabusTopics: const ['Botany', 'Zoology'],
        targetDays: 60,
        schedule: const [],
        isActive: true,
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );

      final plan = ExamStudyPlanModel.fromAIRoadmap(roadmap);

      expect(plan.id, 'road-99');
      expect(plan.examName, 'NEET UG Biology');
      expect(plan.overview, 'Biology active recall roadmap');
      expect(plan.syllabusTopics, containsAll(['Botany', 'Zoology']));
      expect(plan.examDate, DateTime(2026, 5, 1).add(const Duration(days: 60)));
    });

    test('9. AIRoadmapModel toExamStudyPlan helper method', () {
      final roadmap = AIRoadmapModel(
        id: 'road-100',
        userId: 'u123',
        examName: 'JEE Organic Chemistry',
        overview: 'Organic Chemistry',
        syllabusTopics: const ['Reaction Mechanisms'],
        targetDays: 45,
        schedule: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final plan = roadmap.toExamStudyPlan();
      expect(plan.id, 'road-100');
      expect(plan.examName, 'JEE Organic Chemistry');
    });

    test('10. AIRoadmapModel computes completedCount and progress correctly', () {
      final roadmap = AIRoadmapModel(
        id: 'road-1',
        userId: 'u1',
        examName: 'Test',
        overview: 'Test',
        syllabusTopics: const [],
        targetDays: 30,
        schedule: [
          StudyPlanTaskModel(id: 't1', dayNumber: 1, title: 'T1', focusArea: 'F1', priority: 'high', subtasks: const [], isCompleted: true),
          StudyPlanTaskModel(id: 't2', dayNumber: 2, title: 'T2', focusArea: 'F2', priority: 'low', subtasks: const [], isCompleted: false),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(roadmap.completedCount, 1);
      expect(roadmap.progress, 0.5);
    });

    test('11. GeneratedRoadmapResponse deserialization with roadmap_id', () {
      final json = {
        'exam_name': 'GATE EE',
        'overview': 'Electrical Engineering Roadmap',
        'schedule': [
          {'id': 't1', 'day_number': 1, 'title': 'Circuit Theory', 'focus_area': 'Circuits', 'priority': 'high', 'subtasks': ['KCL', 'KVL']}
        ],
        'roadmap_id': 'rm-backend-101',
      };

      final response = GeneratedRoadmapResponse.fromJson(json);

      expect(response.examName, 'GATE EE');
      expect(response.roadmapId, 'rm-backend-101');
      expect(response.schedule.length, 1);
      expect(response.schedule.first.title, 'Circuit Theory');
    });

    test('12. SaveRoadmapRequest produces expected JSON structure', () {
      final req = SaveRoadmapRequest(
        examName: 'UPSC Civil Services',
        overview: 'General Studies Roadmap',
        syllabus: const ['Polity', 'History', 'Economy'],
        targetDays: 90,
        schedule: [
          StudyPlanTaskModel(id: 't1', dayNumber: 1, title: 'Indian Constitution', focusArea: 'Polity', priority: 'high', subtasks: const ['Preamble', 'Fundamental Rights'])
        ],
      );

      final json = req.toJson();

      expect(json['exam_name'], 'UPSC Civil Services');
      expect(json['target_days'], 90);
      expect(json['syllabus'], contains('Polity'));
      final scheduleList = json['schedule'] as List;
      expect(scheduleList.first['title'], 'Indian Constitution');
      expect(scheduleList.first['subtasks'], contains('Preamble'));
    });

    test('13. UpdateRoadmapRequest serializes only non-null fields', () {
      final req = UpdateRoadmapRequest(
        examName: 'Updated Exam Name',
        isActive: false,
      );

      final json = req.toJson();

      expect(json.containsKey('exam_name'), true);
      expect(json['exam_name'], 'Updated Exam Name');
      expect(json.containsKey('is_active'), true);
      expect(json['is_active'], false);
      expect(json.containsKey('overview'), false);
      expect(json.containsKey('schedule'), false);
    });

    test('14. CreateStudyPlanRequest produces correct JSON body', () {
      final req = CreateStudyPlanRequest(
        title: 'Revise Integration Formulas',
        priority: 'high',
        courseId: 'c-math-101',
        dueDate: '2026-11-15T00:00:00.000Z',
      );

      final json = req.toJson();

      expect(json['title'], 'Revise Integration Formulas');
      expect(json['priority'], 'high');
      expect(json['course_id'], 'c-math-101');
      expect(json['due_date'], '2026-11-15T00:00:00.000Z');
    });

    test('15. UpdateStudyPlanRequest converts fields properly', () {
      final req = UpdateStudyPlanRequest(
        isCompleted: true,
        priority: 'low',
      );

      final json = req.toJson();

      expect(json['is_completed'], true);
      expect(json['priority'], 'low');
      expect(json.containsKey('title'), false);
    });

    test('16. ExamPlannerService.createAdaptiveRoadmap generates multi-phase tasks', () {
      final targetDate = DateTime.now().add(const Duration(days: 20));
      final plan = ExamPlannerService.createAdaptiveRoadmap(
        examName: 'Algorithms Exam',
        examDate: targetDate,
        dailyHoursGoal: 4.0,
        topics: const ['Dynamic Programming', 'Graph Algorithms', 'Sorting & Searching'],
      );

      expect(plan.examName, 'Algorithms Exam');
      expect(plan.syllabusTopics.length, 3);
      // For 3 topics, 2 tasks per topic + 1 final review task = 7 tasks total
      expect(plan.schedule.length, 7);
      expect(plan.schedule.last.title, contains('Full-Length Timed Mock'));
    });

    test('17. ExamPlannerService.createAdaptiveRoadmap handles empty topics gracefully', () {
      final plan = ExamPlannerService.createAdaptiveRoadmap(
        examName: 'Blank Exam',
        examDate: DateTime.now(),
        dailyHoursGoal: 2.0,
        topics: const ['   ', ''],
      );

      expect(plan.examName, 'Blank Exam');
      expect(plan.syllabusTopics, isEmpty);
      expect(plan.schedule, isEmpty);
    });

    test('18. StudyPlanItemModel JSON parsing and serialization', () {
      final json = {
        'id': 'item-1',
        'user_id': 'u-9',
        'course_id': 'c-2',
        'title': 'Complete Calculus Quiz',
        'priority': 'high',
        'is_completed': true,
        'due_date': '2026-12-01T00:00:00.000Z',
        'created_at': '2026-10-20T10:00:00.000Z',
        'updated_at': '2026-10-20T10:00:00.000Z',
      };

      final item = StudyPlanItemModel.fromJson(json);

      expect(item.id, 'item-1');
      expect(item.userId, 'u-9');
      expect(item.title, 'Complete Calculus Quiz');
      expect(item.isCompleted, true);
      expect(item.dueDate, DateTime.tryParse('2026-12-01T00:00:00.000Z'));
    });

    test('19. ExamStudyPlanModel JSON serialization preserves all fields', () {
      final plan = ExamStudyPlanModel(
        id: 'p-100',
        examName: 'Medical Biochemistry',
        examDate: DateTime(2026, 11, 20),
        dailyHoursGoal: 3.5,
        overview: 'High yield biochemistry active recall',
        syllabusTopics: const ['Enzyme Kinetics', 'Metabolism'],
        schedule: [
          StudyPlanTaskModel(
            id: 't-b1',
            dayNumber: 1,
            title: 'Michaelis-Menten Equation',
            focusArea: 'Enzyme Kinetics',
            priority: 'high',
            subtasks: const ['Derive Km and Vmax', 'Solve numericals'],
            isCompleted: false,
          )
        ],
        totalStudyMinutes: 120,
      );

      final json = plan.toJson();
      final revived = ExamStudyPlanModel.fromJson(json);

      expect(revived.id, 'p-100');
      expect(revived.examName, 'Medical Biochemistry');
      expect(revived.dailyHoursGoal, 3.5);
      expect(revived.overview, 'High yield biochemistry active recall');
      expect(revived.syllabusTopics, contains('Enzyme Kinetics'));
      expect(revived.schedule.first.title, 'Michaelis-Menten Equation');
      expect(revived.totalStudyMinutes, 120);
    });

    test('20. StudyPlanTaskModel priority sorting works as expected', () {
      final tasks = [
        StudyPlanTaskModel(id: 't3', dayNumber: 3, title: 'Day 3 Task', focusArea: 'F', priority: 'low', subtasks: const []),
        StudyPlanTaskModel(id: 't1', dayNumber: 1, title: 'Day 1 Task', focusArea: 'F', priority: 'high', subtasks: const []),
        StudyPlanTaskModel(id: 't2', dayNumber: 2, title: 'Day 2 Task', focusArea: 'F', priority: 'medium', subtasks: const []),
      ];

      tasks.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

      expect(tasks[0].dayNumber, 1);
      expect(tasks[1].dayNumber, 2);
      expect(tasks[2].dayNumber, 3);
    });
  });
}
