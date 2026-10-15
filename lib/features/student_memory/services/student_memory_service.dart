import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/student_memory.dart';

class StudentMemoryService {
  static const String _prefKey = 'studysilo_student_memory_profile';
  static StudentMemoryService? _instance;
  final Dio _dio = ApiClient().dio;

  StudentMemoryService._internal();

  factory StudentMemoryService() {
    _instance ??= StudentMemoryService._internal();
    return _instance!;
  }

  /// Get student memory profile from local cache first, then sync with backend
  Future<StudentMemoryProfile> getProfile({bool forceRemote = false}) async {
    StudentMemoryProfile? cachedProfile;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
        cachedProfile = StudentMemoryProfile.fromJson(data);
      }
    } catch (_) {}

    // If we have cached profile and don't need forced remote sync, try background refresh or return cached
    if (cachedProfile != null && !forceRemote) {
      // Fire-and-forget sync with backend in background
      _syncFromBackend().then((remoteProfile) {
        if (remoteProfile != null) {
          _saveToLocal(remoteProfile);
        }
      }).catchError((_) {});
      return cachedProfile;
    }

    // Attempt remote fetch
    final remote = await _syncFromBackend();
    if (remote != null) {
      await _saveToLocal(remote);
      return remote;
    }

    return cachedProfile ?? StudentMemoryProfile.defaultProfile();
  }

  /// Fetch latest profile from backend database
  Future<StudentMemoryProfile?> _syncFromBackend() async {
    try {
      final response = await _dio.get(ApiConstants.cognitiveProfile);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        return StudentMemoryProfile.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Save to local SharedPreferences
  Future<void> _saveToLocal(StudentMemoryProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = profile.copyWith(updatedAt: DateTime.now());
      await prefs.setString(_prefKey, jsonEncode(updated.toJson()));
    } catch (_) {}
  }

  /// Sync full profile state to backend database
  Future<void> _syncToRemote(StudentMemoryProfile profile) async {
    try {
      await _dio.put(
        ApiConstants.cognitiveProfile,
        data: {
          'target_exam': profile.targetExam,
          'academic_level': profile.academicLevel,
          'weak_topics': profile.weakTopics,
          'strong_topics': profile.strongTopics,
          'exam_traps_to_watch': profile.examTrapsEncountered,
        },
      );
    } catch (_) {}
  }

  /// Save profile to local storage and sync with backend
  Future<void> saveProfile(StudentMemoryProfile profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now());
    await _saveToLocal(updated);
    await _syncToRemote(updated);
  }

  /// Update target exam and academic level
  Future<StudentMemoryProfile> updateExamTarget({
    required String targetExam,
    required String academicLevel,
  }) async {
    final current = await getProfile();
    final updated = current.copyWith(
      targetExam: targetExam.trim(),
      academicLevel: academicLevel.trim(),
      updatedAt: DateTime.now(),
    );
    await saveProfile(updated);
    return updated;
  }

  /// Run an on-demand AI Cognitive Diagnosis
  Future<StudentMemoryProfile> diagnoseProfile() async {
    try {
      final response = await _dio.post(ApiConstants.cognitiveDiagnose);
      if (response.statusCode == 200 && response.data != null && response.data['data'] != null) {
        // Diagnosis returned, now fetch the refreshed full profile
        final refreshed = await _syncFromBackend();
        if (refreshed != null) {
          await _saveToLocal(refreshed);
          return refreshed;
        }
      }
    } catch (_) {}

    // Fallback: refresh profile
    return getProfile(forceRemote: true);
  }

  /// Promote topic to Mastered
  Future<StudentMemoryProfile> promoteTopic(String topic) async {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) return getProfile();

    try {
      final response = await _dio.post(
        ApiConstants.cognitivePromote,
        data: {'topic': trimmed},
      );
      if (response.statusCode == 200 && response.data != null && response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        final profile = StudentMemoryProfile.fromJson(data);
        await _saveToLocal(profile);
        return profile;
      }
    } catch (_) {}

    // Local fallback
    return moveToMastered(trimmed);
  }

  /// Demote topic to Weak / Needs Focus
  Future<StudentMemoryProfile> demoteTopic(String topic) async {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) return getProfile();

    try {
      final response = await _dio.post(
        ApiConstants.cognitiveDemote,
        data: {'topic': trimmed},
      );
      if (response.statusCode == 200 && response.data != null && response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        final profile = StudentMemoryProfile.fromJson(data);
        await _saveToLocal(profile);
        return profile;
      }
    } catch (_) {}

    // Local fallback
    return moveToWeak(trimmed);
  }

  /// Delete topic from profile completely
  Future<StudentMemoryProfile> deleteTopic(String topic) async {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) return getProfile();

    try {
      final response = await _dio.delete(
        ApiConstants.cognitiveTopics,
        data: {'topic': trimmed},
      );
      if (response.statusCode == 200 && response.data != null && response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        final profile = StudentMemoryProfile.fromJson(data);
        await _saveToLocal(profile);
        return profile;
      }
    } catch (_) {}

    final current = await getProfile();
    final target = trimmed.toLowerCase();
    final updatedWeak = List<String>.from(current.weakTopics)..removeWhere((w) => w.trim().toLowerCase() == target);
    final updatedStrong = List<String>.from(current.strongTopics)..removeWhere((s) => s.trim().toLowerCase() == target);
    final updatedMastery = Map<String, int>.from(current.topicMastery)..remove(trimmed);

    final updated = current.copyWith(
      weakTopics: updatedWeak,
      strongTopics: updatedStrong,
      topicMastery: updatedMastery,
      updatedAt: DateTime.now(),
    );
    await saveProfile(updated);
    return updated;
  }

  /// Record activity
  Future<void> recordActivity({
    required String activityType,
    String topic = '',
    int durationMinutes = 2,
  }) async {
    try {
      await _dio.post(
        ApiConstants.cognitiveActivity,
        data: {
          'activity_type': activityType,
          'topic': topic,
          'duration_minutes': durationMinutes,
        },
      );
    } catch (_) {}
  }

  /// Add single or multiple weak topics
  Future<StudentMemoryProfile> addWeakTopic(String topic) async {
    final current = await getProfile();
    final items = topic
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (items.isEmpty) return current;

    final updatedWeak = List<String>.from(current.weakTopics);
    final updatedStrong = List<String>.from(current.strongTopics);

    for (final item in items) {
      if (!updatedWeak.any((w) => w.toLowerCase() == item.toLowerCase())) {
        updatedWeak.add(item);
      }
      updatedStrong.removeWhere((s) => s.toLowerCase() == item.toLowerCase());
    }

    final updated = current.copyWith(
      weakTopics: updatedWeak,
      strongTopics: updatedStrong,
      updatedAt: DateTime.now(),
    );
    await saveProfile(updated);
    return updated;
  }

  /// Remove weak topic
  Future<StudentMemoryProfile> removeWeakTopic(String topic) async {
    return deleteTopic(topic);
  }

  /// Add single or multiple strong topics
  Future<StudentMemoryProfile> addStrongTopic(String topic) async {
    final current = await getProfile();
    final items = topic
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (items.isEmpty) return current;

    final updatedStrong = List<String>.from(current.strongTopics);
    final updatedWeak = List<String>.from(current.weakTopics);

    for (final item in items) {
      if (!updatedStrong.any((s) => s.toLowerCase() == item.toLowerCase())) {
        updatedStrong.add(item);
      }
      updatedWeak.removeWhere((w) => w.toLowerCase() == item.toLowerCase());
    }

    final updated = current.copyWith(
      strongTopics: updatedStrong,
      weakTopics: updatedWeak,
      updatedAt: DateTime.now(),
    );
    await saveProfile(updated);
    return updated;
  }

  /// Remove strong topic
  Future<StudentMemoryProfile> removeStrongTopic(String topic) async {
    return deleteTopic(topic);
  }

  /// Move weak topic to mastered / strong
  Future<StudentMemoryProfile> moveToMastered(String topic) async {
    return addStrongTopic(topic);
  }

  /// Move strong topic to weak
  Future<StudentMemoryProfile> moveToWeak(String topic) async {
    return addWeakTopic(topic);
  }
}
