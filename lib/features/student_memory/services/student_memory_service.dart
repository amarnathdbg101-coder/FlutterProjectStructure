import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/student_memory.dart';
import 'smart_ai_context_helper.dart';

class StudentMemoryService {
  static const String _prefKey = 'studysilo_student_memory_profile';
  static const String _smartContextPrefKey = 'studysilo_smart_context';
  static StudentMemoryService? _instance;
  static StudentMemoryProfile? _cachedProfile;
  final Dio _dio = ApiClient().dio;

  StudentMemoryService._internal();

  factory StudentMemoryService() {
    _instance ??= StudentMemoryService._internal();
    return _instance!;
  }

  /// Synchronous retrieval of cached student memory profile (0ms instant access)
  static StudentMemoryProfile? getCachedProfileSync() => _cachedProfile;

  /// Get student memory profile from local cache first, then sync with backend
  Future<StudentMemoryProfile> getProfile({bool forceRemote = false}) async {
    StudentMemoryProfile? cachedProfile;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
        cachedProfile = StudentMemoryProfile.fromJson(data);
        _cachedProfile = cachedProfile;
      }
    } catch (_) {}

    // Also prime smart context in background
    fetchSmartContext(targetExam: cachedProfile?.targetExam).catchError((_) => null);

    if (forceRemote || cachedProfile == null) {
      final remote = await _syncFromBackend();
      if (remote != null) {
        _cachedProfile = remote;
        await _saveToLocal(remote);
        fetchSmartContext(targetExam: remote.targetExam, forceRemote: true).catchError((_) => null);
        return remote;
      }
      _cachedProfile = cachedProfile ?? StudentMemoryProfile.defaultProfile();
      return _cachedProfile!;
    }

    // Fire-and-forget sync with backend in background
    _syncFromBackend().then((remoteProfile) {
      if (remoteProfile != null) {
        if (_cachedProfile == null || remoteProfile.updatedAt.isAfter(_cachedProfile!.updatedAt)) {
          _cachedProfile = remoteProfile;
          _saveToLocal(remoteProfile);
          fetchSmartContext(targetExam: remoteProfile.targetExam, forceRemote: true).catchError((_) => null);
        }
      }
    }).catchError((_) {});

    return cachedProfile;
  }

  /// Fetch dynamic smart context (prompts, syllabus suggestions, hints) from PostgreSQL / Go Cognitive Engine
  Future<SmartContextResponse?> fetchSmartContext({
    String? tutorMode,
    String? targetExam,
    bool forceRemote = false,
  }) async {
    // 1. Try local cache first for instant startup
    if (!forceRemote) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_smartContextPrefKey);
        if (raw != null && raw.isNotEmpty) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final cached = SmartContextResponse.fromJson(data);
          SmartAiContextHelper.setServerContext(cached);
          // background sync
          _syncSmartContextFromBackend(tutorMode: tutorMode, targetExam: targetExam).then((remote) {
            if (remote != null) {
              _saveSmartContextToLocal(remote);
              SmartAiContextHelper.setServerContext(remote);
            }
          }).catchError((_) {});
          return cached;
        }
      } catch (_) {}
    }

    final remote = await _syncSmartContextFromBackend(tutorMode: tutorMode, targetExam: targetExam);
    if (remote != null) {
      await _saveSmartContextToLocal(remote);
      SmartAiContextHelper.setServerContext(remote);
      return remote;
    }
    return null;
  }

  Future<SmartContextResponse?> _syncSmartContextFromBackend({String? tutorMode, String? targetExam}) async {
    try {
      final response = await _dio.get(
        ApiConstants.cognitiveSmartContext,
        queryParameters: {
          if (tutorMode != null && tutorMode.isNotEmpty) 'mode': tutorMode,
          if (targetExam != null && targetExam.isNotEmpty) 'exam': targetExam,
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        return SmartContextResponse.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveSmartContextToLocal(SmartContextResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_smartContextPrefKey, jsonEncode(response.toJson()));
    } catch (_) {}
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
      await prefs.setString(_prefKey, jsonEncode(profile.toJson()));
    } catch (_) {}
  }

  /// Sync full profile state to backend database
  Future<void> _syncToRemote(StudentMemoryProfile profile) async {
    try {
      final response = await _dio.put(
        ApiConstants.cognitiveProfile,
        data: {
          'target_exam': profile.targetExam,
          'academic_level': profile.academicLevel,
          'custom_instructions': profile.customInstructions,
          'weak_topics': profile.weakTopics,
          'strong_topics': profile.strongTopics,
          'exam_traps_to_watch': profile.examTrapsEncountered,
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null &&
          response.data['data'] != null) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        final synced = StudentMemoryProfile.fromJson(data);
        _cachedProfile = synced;
        await _saveToLocal(synced);
      }
    } catch (_) {}
  }

  /// Save profile to local storage and sync with backend
  Future<void> saveProfile(StudentMemoryProfile profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now());
    _cachedProfile = updated;
    await _saveToLocal(updated);
    await _syncToRemote(updated);
  }

  /// Update target exam and academic level, and optional custom instructions
  Future<StudentMemoryProfile> updateExamTarget({
    required String targetExam,
    required String academicLevel,
    String? customInstructions,
  }) async {
    final current = _cachedProfile ?? await getProfile();
    final updated = current.copyWith(
      targetExam: targetExam.trim(),
      academicLevel: academicLevel.trim(),
      customInstructions: customInstructions != null ? customInstructions.trim() : current.customInstructions,
      updatedAt: DateTime.now(),
    );
    _cachedProfile = updated;
    await _saveToLocal(updated);
    await _syncToRemote(updated);
    fetchSmartContext(targetExam: updated.targetExam, forceRemote: true).catchError((_) => null);
    return updated;
  }

  /// Update custom instructions / teaching style specifically
  Future<StudentMemoryProfile> updateCustomInstructions(String instructions) async {
    final current = _cachedProfile ?? await getProfile();
    final updated = current.copyWith(
      customInstructions: instructions.trim(),
      updatedAt: DateTime.now(),
    );
    _cachedProfile = updated;
    await _saveToLocal(updated);
    await _syncToRemote(updated);
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

  /// Clear all topics and topic mastery from profile and sync to server
  Future<StudentMemoryProfile> clearAllTopics() async {
    final current = await getProfile();
    final updated = current.copyWith(
      weakTopics: const [],
      strongTopics: const [],
      topicMastery: const {},
      examTrapsEncountered: const [],
      updatedAt: DateTime.now(),
    );
    await saveProfile(updated);
    return updated;
  }
}
