import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/study_plan_model.dart';

/// StudyPlanRepository - AI Exam Roadmaps ke liye full CRUD operations
/// Backend ke saath communicate karta hai REST API through Dio
class StudyPlanRepository {
  final Dio _dio = ApiClient().dio;

  // ─── AI Roadmap CRUD ────────────────────────────────────────────────────

  /// [CREATE] AI se generate hue roadmap ko DB mein save karo
  /// Backend POST /api/v1/roadmaps
  Future<AIRoadmapModel?> saveRoadmap(SaveRoadmapRequest req) async {
    try {
      final response = await _dio.post(
        ApiConstants.roadmaps,
        data: req.toJson(),
      );
      if (_isSuccess(response) && response.data['data'] != null) {
        return AIRoadmapModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } on DioException catch (e) {
      _logError('saveRoadmap', e);
    }
    return null;
  }

  /// [READ] Ek roadmap fetch karo by ID
  /// Backend GET /api/v1/roadmaps/{id}
  Future<AIRoadmapModel?> getRoadmapById(String id) async {
    try {
      final response = await _dio.get('${ApiConstants.roadmaps}/$id');
      if (_isSuccess(response) && response.data['data'] != null) {
        return AIRoadmapModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } on DioException catch (e) {
      _logError('getRoadmapById', e);
    }
    return null;
  }

  /// [READ LIST] User ke saare saved roadmaps fetch karo
  /// Backend GET /api/v1/roadmaps
  Future<List<AIRoadmapModel>> listRoadmaps() async {
    try {
      final response = await _dio.get(ApiConstants.roadmaps);
      if (_isSuccess(response) && response.data['data'] != null) {
        final list = response.data['data'] as List;
        return list
            .map((e) => AIRoadmapModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } on DioException catch (e) {
      _logError('listRoadmaps', e);
    }
    return [];
  }

  /// [UPDATE] Existing roadmap ko partially update karo (PATCH)
  /// Backend PATCH /api/v1/roadmaps/{id}
  Future<AIRoadmapModel?> updateRoadmap(
    String id,
    UpdateRoadmapRequest req,
  ) async {
    try {
      final response = await _dio.patch(
        '${ApiConstants.roadmaps}/$id',
        data: req.toJson(),
      );
      if (_isSuccess(response) && response.data['data'] != null) {
        return AIRoadmapModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } on DioException catch (e) {
      _logError('updateRoadmap', e);
    }
    return null;
  }

  /// [DELETE] Roadmap permanently delete karo
  /// Backend DELETE /api/v1/roadmaps/{id}
  Future<bool> deleteRoadmap(String id) async {
    try {
      final response = await _dio.delete('${ApiConstants.roadmaps}/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      _logError('deleteRoadmap', e);
      return false;
    }
  }

  // ─── Study Plans CRUD (Simple Task Goals) ───────────────────────────────

  /// Study plans (simple task items) fetch karo
  /// Backend GET /api/v1/study-plans
  Future<List<StudyPlanItemModel>> listStudyPlans() async {
    try {
      final response = await _dio.get(ApiConstants.studyPlans);
      if (_isSuccess(response) && response.data['data'] != null) {
        final list = response.data['data'] as List;
        return list
            .map((e) => StudyPlanItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } on DioException catch (e) {
      _logError('listStudyPlans', e);
    }
    return [];
  }

  /// Naya study plan task create karo
  /// Backend POST /api/v1/study-plans
  Future<StudyPlanItemModel?> createStudyPlan(CreateStudyPlanRequest req) async {
    try {
      final response = await _dio.post(
        ApiConstants.studyPlans,
        data: req.toJson(),
      );
      if (response.statusCode == 201 && response.data['data'] != null) {
        return StudyPlanItemModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } on DioException catch (e) {
      _logError('createStudyPlan', e);
    }
    return null;
  }

  /// Study plan task update karo (mark complete, change priority)
  /// Backend PATCH /api/v1/study-plans/{id}
  Future<StudyPlanItemModel?> updateStudyPlan(
    String id,
    UpdateStudyPlanRequest req,
  ) async {
    try {
      final response = await _dio.patch(
        '${ApiConstants.studyPlans}/$id',
        data: req.toJson(),
      );
      if (_isSuccess(response) && response.data['data'] != null) {
        return StudyPlanItemModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } on DioException catch (e) {
      _logError('updateStudyPlan', e);
    }
    return null;
  }

  /// Study plan task delete karo
  /// Backend DELETE /api/v1/study-plans/{id}
  Future<bool> deleteStudyPlan(String id) async {
    try {
      final response = await _dio.delete('${ApiConstants.studyPlans}/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      _logError('deleteStudyPlan', e);
      return false;
    }
  }

  /// AI se roadmap generate karo (aur optionally DB mein save bhi karo)
  /// Backend POST /api/v1/study-plans/generate
  Future<GeneratedRoadmapResponse?> generateAIRoadmap({
    required String examName,
    required List<String> syllabus,
    required int targetDays,
    bool saveToDB = false, // true karo toh auto-save DB mein
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.generateStudyPlan,
        data: {
          'exam_name': examName,
          'syllabus': syllabus,
          'target_days': targetDays,
          'save_to_db': saveToDB,
        },
      );
      if (_isSuccess(response) && response.data['data'] != null) {
        return GeneratedRoadmapResponse.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } on DioException catch (e) {
      _logError('generateAIRoadmap', e);
    }
    return null;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  bool _isSuccess(Response response) =>
      response.statusCode == 200 || response.statusCode == 201;

  void _logError(String method, DioException e) {
    // Production mein proper logging use karo
    // ignore: avoid_print
    print('[StudyPlanRepository.$method] Error: ${e.message}');
  }
}
