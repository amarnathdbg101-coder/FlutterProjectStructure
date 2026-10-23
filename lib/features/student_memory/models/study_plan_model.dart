/// Model for a structured AI Study Plan task item
class StudyPlanTaskModel {
  final String id;
  final int dayNumber;
  final String title;
  final String focusArea; // "Theory & Concept", "Derivation & Math", "Practice Numericals", "PYQ Active Recall", "Spaced Review"
  final String priority;  // "high", "medium", "low"
  final List<String> subtasks;
  bool isCompleted;

  StudyPlanTaskModel({
    required this.id,
    required this.dayNumber,
    required this.title,
    required this.focusArea,
    required this.priority,
    required this.subtasks,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'day_number': dayNumber,
    'title': title,
    'focus_area': focusArea,
    'priority': priority,
    'subtasks': subtasks,
    'is_completed': isCompleted,
  };

  factory StudyPlanTaskModel.fromJson(Map<String, dynamic> json) => StudyPlanTaskModel(
    id: json['id']?.toString() ?? 'task-${DateTime.now().microsecondsSinceEpoch}',
    dayNumber: int.tryParse(json['day_number']?.toString() ?? '') ?? (json['day_number'] as num?)?.toInt() ?? 1,
    title: json['title']?.toString() ?? 'Study Task',
    focusArea: json['focus_area']?.toString() ?? 'Core Concept',
    priority: json['priority']?.toString() ?? 'medium',
    subtasks: (json['subtasks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    isCompleted: json['is_completed'] == true,
  );
}

/// Comprehensive model for an AI Exam Study Plan & Spaced Repetition Roadmap
class ExamStudyPlanModel {
  final String? id;
  final String examName;
  final DateTime examDate;
  final double dailyHoursGoal;
  final String overview;
  final List<String> syllabusTopics;
  final List<StudyPlanTaskModel> schedule;
  final int totalStudyMinutes;

  ExamStudyPlanModel({
    this.id,
    required this.examName,
    required this.examDate,
    this.dailyHoursGoal = 4.0,
    required this.overview,
    required this.syllabusTopics,
    required this.schedule,
    this.totalStudyMinutes = 0,
  });

  int get daysRemaining {
    final now = DateTime.now();
    final diff = examDate.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  int get completedTaskCount => schedule.where((t) => t.isCompleted).length;

  double get progressPercentage => schedule.isEmpty ? 0 : (completedTaskCount / schedule.length);

  ExamStudyPlanModel copyWith({
    String? id,
    String? examName,
    DateTime? examDate,
    double? dailyHoursGoal,
    String? overview,
    List<String>? syllabusTopics,
    List<StudyPlanTaskModel>? schedule,
    int? totalStudyMinutes,
  }) {
    return ExamStudyPlanModel(
      id: id ?? this.id,
      examName: examName ?? this.examName,
      examDate: examDate ?? this.examDate,
      dailyHoursGoal: dailyHoursGoal ?? this.dailyHoursGoal,
      overview: overview ?? this.overview,
      syllabusTopics: syllabusTopics ?? this.syllabusTopics,
      schedule: schedule ?? this.schedule,
      totalStudyMinutes: totalStudyMinutes ?? this.totalStudyMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'exam_name': examName,
    'exam_date': examDate.toIso8601String(),
    'daily_hours_goal': dailyHoursGoal,
    'overview': overview,
    'syllabus_topics': syllabusTopics,
    'schedule': schedule.map((s) => s.toJson()).toList(),
    'total_study_minutes': totalStudyMinutes,
  };

  factory ExamStudyPlanModel.fromJson(Map<String, dynamic> json) {
    return ExamStudyPlanModel(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      examName: json['exam_name']?.toString() ?? 'Target Exam',
      examDate: json['exam_date'] != null
          ? DateTime.tryParse(json['exam_date']) ?? DateTime.now().add(const Duration(days: 60))
          : DateTime.now().add(const Duration(days: 60)),
      dailyHoursGoal: (json['daily_hours_goal'] as num?)?.toDouble() ?? 4.0,
      overview: json['overview']?.toString() ?? '',
      syllabusTopics: (json['syllabus_topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((e) => StudyPlanTaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      totalStudyMinutes: (json['total_study_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  factory ExamStudyPlanModel.fromAIRoadmap(AIRoadmapModel roadmap) {
    final targetDays = roadmap.targetDays > 0 ? roadmap.targetDays : 30;
    final examDate = roadmap.createdAt.add(Duration(days: targetDays));
    return ExamStudyPlanModel(
      id: roadmap.id,
      examName: roadmap.examName,
      examDate: examDate,
      dailyHoursGoal: 4.0,
      overview: roadmap.overview,
      syllabusTopics: roadmap.syllabusTopics,
      schedule: roadmap.schedule,
    );
  }
}

// ─── DB-Persisted AI Roadmap Models ────────────────────────────────────────

/// AIRoadmapModel - Database mein save hue roadmap ka Flutter model
/// Backend ke ai_roadmaps table se map hota hai
class AIRoadmapModel {
  final String id;
  final String userId;
  final String examName;
  final String overview;
  final List<String> syllabusTopics;
  final int targetDays;
  final List<StudyPlanTaskModel> schedule;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AIRoadmapModel({
    required this.id,
    required this.userId,
    required this.examName,
    required this.overview,
    required this.syllabusTopics,
    required this.targetDays,
    required this.schedule,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  int get completedCount => schedule.where((t) => t.isCompleted).length;
  double get progress => schedule.isEmpty ? 0.0 : completedCount / schedule.length;

  ExamStudyPlanModel toExamStudyPlan() {
    return ExamStudyPlanModel.fromAIRoadmap(this);
  }

  factory AIRoadmapModel.fromJson(Map<String, dynamic> json) {
    return AIRoadmapModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      examName: json['exam_name']?.toString() ?? 'Target Exam',
      overview: json['overview']?.toString() ?? '',
      syllabusTopics: (json['syllabus_topics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      targetDays: (json['target_days'] as num?)?.toInt() ?? 30,
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((e) => StudyPlanTaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'exam_name': examName,
    'overview': overview,
    'syllabus_topics': syllabusTopics,
    'target_days': targetDays,
    'schedule': schedule.map((s) => s.toJson()).toList(),
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// GeneratedRoadmapResponse - AI generate response (DB save ke baad roadmap_id bhi aata hai)
class GeneratedRoadmapResponse {
  final String examName;
  final String overview;
  final List<StudyPlanTaskModel> schedule;
  final String? roadmapId; // Agar save_to_db=true tha toh DB mein save hue roadmap ka ID

  GeneratedRoadmapResponse({
    required this.examName,
    required this.overview,
    required this.schedule,
    this.roadmapId,
  });

  factory GeneratedRoadmapResponse.fromJson(Map<String, dynamic> json) {
    return GeneratedRoadmapResponse(
      examName: json['exam_name']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((e) => StudyPlanTaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      roadmapId: json['roadmap_id']?.toString(),
    );
  }
}

// ─── Simple Study Plan Task Item (non-AI, manual tasks) ────────────────────

/// StudyPlanItemModel - Backend study_plans table ka Flutter model
class StudyPlanItemModel {
  final String id;
  final String userId;
  final String? courseId;
  final String title;
  final String priority; // low, medium, high
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyPlanItemModel({
    required this.id,
    required this.userId,
    this.courseId,
    required this.title,
    this.priority = 'medium',
    this.isCompleted = false,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyPlanItemModel.fromJson(Map<String, dynamic> json) {
    return StudyPlanItemModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      courseId: json['course_id']?.toString(),
      title: json['title']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'medium',
      isCompleted: json['is_completed'] as bool? ?? false,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'course_id': courseId,
    'title': title,
    'priority': priority,
    'is_completed': isCompleted,
    'due_date': dueDate?.toIso8601String(),
  };
}

// ─── Request DTOs ──────────────────────────────────────────────────────────

/// SaveRoadmapRequest - Generate hue roadmap ko DB mein save karne ke liye
class SaveRoadmapRequest {
  final String examName;
  final String overview;
  final List<String> syllabus;
  final int targetDays;
  final List<StudyPlanTaskModel> schedule;

  SaveRoadmapRequest({
    required this.examName,
    required this.overview,
    required this.syllabus,
    required this.targetDays,
    required this.schedule,
  });

  Map<String, dynamic> toJson() => {
    'exam_name': examName,
    'overview': overview,
    'syllabus': syllabus,
    'target_days': targetDays,
    'schedule': schedule.map((t) => {
      'day_number': t.dayNumber,
      'title': t.title,
      'focus_area': t.focusArea,
      'priority': t.priority,
      'subtasks': t.subtasks,
    }).toList(),
  };
}

/// UpdateRoadmapRequest - Roadmap PATCH ke liye (sirf changed fields)
class UpdateRoadmapRequest {
  final String? examName;
  final String? overview;
  final bool? isActive;
  final List<StudyPlanTaskModel>? schedule;

  UpdateRoadmapRequest({
    this.examName,
    this.overview,
    this.isActive,
    this.schedule,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (examName != null) data['exam_name'] = examName;
    if (overview != null) data['overview'] = overview;
    if (isActive != null) data['is_active'] = isActive;
    if (schedule != null) {
      data['schedule'] = schedule!.map((t) => {
        'day_number': t.dayNumber,
        'title': t.title,
        'focus_area': t.focusArea,
        'priority': t.priority,
        'subtasks': t.subtasks,
      }).toList();
    }
    return data;
  }
}

/// CreateStudyPlanRequest - Manual study plan task create karne ke liye
class CreateStudyPlanRequest {
  final String title;
  final String priority;
  final String? courseId;
  final String? dueDate; // ISO 8601 format

  CreateStudyPlanRequest({
    required this.title,
    this.priority = 'medium',
    this.courseId,
    this.dueDate,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'priority': priority,
    if (courseId != null) 'course_id': courseId,
    if (dueDate != null) 'due_date': dueDate,
  };
}

/// UpdateStudyPlanRequest - Study plan task partial update ke liye
class UpdateStudyPlanRequest {
  final String? title;
  final bool? isCompleted;
  final String? priority;

  UpdateStudyPlanRequest({
    this.title,
    this.isCompleted,
    this.priority,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (isCompleted != null) data['is_completed'] = isCompleted;
    if (priority != null) data['priority'] = priority;
    return data;
  }
}

