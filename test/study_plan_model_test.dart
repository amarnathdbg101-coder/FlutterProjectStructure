import 'package:flutter_test/flutter_test.dart';
import 'package:studysilo/features/student_memory/services/exam_planner_service.dart';

void main() {
  group('ExamStudyPlanModel Tests', () {
    test('Calculates progress percentage, completed tasks, and remaining days correctly', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 10));

      final plan = ExamStudyPlanModel(
        examName: 'GATE CS 2026',
        examDate: targetDate,
        dailyHoursGoal: 3.5,
        overview: 'GATE preparation roadmap',
        syllabusTopics: ['Operating Systems', 'DBMS', 'Algorithms'],
        schedule: [
          StudyPlanTaskModel(
            id: 'task-1',
            dayNumber: 1,
            title: 'OS Process Management',
            focusArea: 'Operating Systems',
            priority: 'High',
            subtasks: ['Process States', 'CPU Scheduling algorithms'],
            isCompleted: true,
          ),
          StudyPlanTaskModel(
            id: 'task-2',
            dayNumber: 2,
            title: 'DBMS Normalization',
            focusArea: 'DBMS',
            priority: 'High',
            subtasks: ['1NF, 2NF, 3NF', 'BCNF vs 3NF'],
            isCompleted: false,
          ),
        ],
        totalStudyMinutes: 50,
      );

      expect(plan.completedTaskCount, 1);
      expect(plan.progressPercentage, 0.5);
      expect(plan.daysRemaining, greaterThanOrEqualTo(9));
      expect(plan.daysRemaining, lessThanOrEqualTo(10));
    });

    test('JSON serialization & deserialization works seamlessly', () {
      final plan = ExamStudyPlanModel(
        examName: 'Midterm Physics',
        examDate: DateTime(2026, 12, 1),
        dailyHoursGoal: 2.0,
        overview: 'Comprehensive revision plan',
        syllabusTopics: ['Thermodynamics', 'Optics'],
        schedule: [
          StudyPlanTaskModel(
            id: 'task-p1',
            dayNumber: 1,
            title: 'Laws of Thermodynamics',
            focusArea: 'Thermodynamics',
            priority: 'High',
            subtasks: ['First law', 'Heat engine'],
            isCompleted: false,
          ),
        ],
        totalStudyMinutes: 25,
      );

      final jsonMap = plan.toJson();
      final revivedPlan = ExamStudyPlanModel.fromJson(jsonMap);

      expect(revivedPlan.examName, 'Midterm Physics');
      expect(revivedPlan.syllabusTopics, contains('Thermodynamics'));
      expect(revivedPlan.schedule.length, 1);
      expect(revivedPlan.schedule.first.title, 'Laws of Thermodynamics');
      expect(revivedPlan.totalStudyMinutes, 25);
    });

    test('Local fallback generation produces multi-phase spaced repetition tasks', () {
      final targetDate = DateTime.now().add(const Duration(days: 14));
      final generatedPlan = ExamPlannerService.createAdaptiveRoadmap(
        examName: 'Data Structures Final',
        examDate: targetDate,
        dailyHoursGoal: 3.0,
        topics: ['Trees & Graphs', 'Dynamic Programming', 'Hashing'],
      );

      expect(generatedPlan.examName, 'Data Structures Final');
      expect(generatedPlan.syllabusTopics.length, 3);
      expect(generatedPlan.schedule.isNotEmpty, true);
      // Ensure tasks span across the syllabus topics
      final titles = generatedPlan.schedule.map((t) => t.title).join(' ');
      expect(titles, contains('Trees & Graphs'));
      expect(titles, contains('Dynamic Programming'));
    });
  });
}
