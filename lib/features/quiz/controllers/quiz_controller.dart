import 'dart:async';
import 'package:flutter/material.dart';
import '../models/quiz_model.dart';
import '../repositories/quiz_repository.dart';

class QuizController extends ChangeNotifier {
  final QuizRepository _repository = QuizRepository();

  List<QuizModel> _quizzes = [];
  QuizModel? _activeQuiz;
  int _currentQuestionIndex = 0;
  final Map<String, int> _selectedAnswers = {}; // questionId -> optionIndex
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  QuizSubmissionResponseModel? _lastResult;
  CognitiveProfileModel _profile = CognitiveProfileModel();

  Timer? _timer;
  int _timeRemainingSeconds = 0;

  List<QuizModel> get quizzes => _quizzes;
  QuizModel? get activeQuiz => _activeQuiz;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<String, int> get selectedAnswers => _selectedAnswers;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  QuizSubmissionResponseModel? get lastResult => _lastResult;
  CognitiveProfileModel get profile => _profile;
  int get timeRemainingSeconds => _timeRemainingSeconds;

  QuizQuestionModel? get currentQuestion {
    if (_activeQuiz == null || _activeQuiz!.questions.isEmpty) return null;
    if (_currentQuestionIndex >= 0 && _currentQuestionIndex < _activeQuiz!.questions.length) {
      return _activeQuiz!.questions[_currentQuestionIndex];
    }
    return null;
  }

  Future<void> loadQuizzesAndProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getQuizzes(),
        _repository.getCognitiveProfile(),
      ]);
      _quizzes = results[0] as List<QuizModel>;
      _profile = results[1] as CognitiveProfileModel;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startQuiz(QuizModel quiz) {
    _activeQuiz = quiz;
    _currentQuestionIndex = 0;
    _selectedAnswers.clear();
    _lastResult = null;
    _timeRemainingSeconds = quiz.totalQuestions * 90; // 90 seconds per question

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemainingSeconds > 0) {
        _timeRemainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
        submitActiveQuiz();
      }
    });

    notifyListeners();
  }

  void selectOption(String questionId, int optionIndex) {
    _selectedAnswers[questionId] = optionIndex;
    notifyListeners();
  }

  void nextQuestion() {
    if (_activeQuiz != null && _currentQuestionIndex < _activeQuiz!.questions.length - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  void prevQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  Future<void> submitActiveQuiz() async {
    if (_activeQuiz == null || _isSubmitting) return;

    _timer?.cancel();
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> answersPayload = [];
      for (final q in _activeQuiz!.questions) {
        answersPayload.add({
          'question_id': q.id,
          'selected_option': _selectedAnswers[q.id] ?? -1,
        });
      }

      final totalAllowed = _activeQuiz!.totalQuestions * 90;
      final timeTaken = totalAllowed - _timeRemainingSeconds;

      final result = await _repository.submitQuiz(
        quizId: _activeQuiz!.id,
        answers: answersPayload,
        timeTakenSeconds: timeTaken > 0 ? timeTaken : 30,
      );

      _lastResult = result;
      // Refresh cognitive profile stats
      _profile = await _repository.getCognitiveProfile();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<QuizModel> generateAndStartQuiz({
    required String topic,
    String? courseId,
    String? noteId,
    String difficulty = 'adaptive',
    int questionCount = 5,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final quiz = await _repository.generateQuiz(
        topic: topic,
        courseId: courseId,
        noteId: noteId,
        difficulty: difficulty,
        questionCount: questionCount,
      );
      _quizzes.insert(0, quiz);
      startQuiz(quiz);
      return quiz;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
