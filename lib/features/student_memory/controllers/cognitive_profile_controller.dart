import 'package:flutter/material.dart';
import '../models/student_memory.dart';
import '../services/student_memory_service.dart';

class CognitiveProfileController extends ChangeNotifier {
  final StudentMemoryService _service = StudentMemoryService();

  StudentMemoryProfile _profile = StudentMemoryProfile.defaultProfile();
  bool _isLoading = false;
  bool _isDiagnosing = false;
  String? _errorMessage;

  StudentMemoryProfile get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isDiagnosing => _isDiagnosing;
  String? get errorMessage => _errorMessage;

  int get readinessScore => _profile.readinessScore;
  int get studyStreak => _profile.studyStreakDays;
  int get doubtsAsked => _profile.totalDoubtsAsked;
  int get quizzesTaken => _profile.totalQuizzesTaken;
  double get avgScore => _profile.averageQuizScore;

  List<String> get weakTopics => _profile.weakTopics;
  List<String> get strongTopics => _profile.strongTopics;
  List<String> get examTraps => _profile.examTrapsEncountered;
  Map<String, int> get topicMastery => _profile.topicMastery;
  List<String> get recommendedActions => _profile.recommendedActions;
  String get aiSummary => _profile.aiSummary;

  Future<void> loadProfile({bool forceRemote = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _service.getProfile(forceRemote: forceRemote);
    } catch (e) {
      _errorMessage = 'Failed to load profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> runDiagnosis() async {
    _isDiagnosing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _service.diagnoseProfile();
      return true;
    } catch (e) {
      _errorMessage = 'Diagnosis failed: $e';
      return false;
    } finally {
      _isDiagnosing = false;
      notifyListeners();
    }
  }

  Future<void> updateGoals({
    required String targetExam,
    required String academicLevel,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _service.updateExamTarget(
        targetExam: targetExam,
        academicLevel: academicLevel,
      );
    } catch (e) {
      _errorMessage = 'Failed to update exam goals: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> promoteTopic(String topic) async {
    try {
      _profile = await _service.promoteTopic(topic);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to promote topic: $e';
      notifyListeners();
    }
  }

  Future<void> demoteTopic(String topic) async {
    try {
      _profile = await _service.demoteTopic(topic);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to mark for focus: $e';
      notifyListeners();
    }
  }

  Future<void> deleteTopic(String topic) async {
    try {
      _profile = await _service.deleteTopic(topic);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to remove topic: $e';
      notifyListeners();
    }
  }

  Future<void> addCustomTopic(String topic, {bool isWeak = true}) async {
    try {
      if (isWeak) {
        _profile = await _service.addWeakTopic(topic);
      } else {
        _profile = await _service.addStrongTopic(topic);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to add topic: $e';
      notifyListeners();
    }
  }

  Future<void> clearAllTopics() async {
    _isLoading = true;
    notifyListeners();
    try {
      _profile = await _service.clearAllTopics();
    } catch (e) {
      _errorMessage = 'Failed to clear topics: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
