import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/storage/hive_storage.dart';
import '../../../core/network/api_client.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';
import '../repositories/ai_tutor_repository.dart';

enum TutorMode {
  academic,
  pyqStrategist,
  feynman,
  trapHunter,
  derivation,
  socratic,
}

extension TutorModeExtension on TutorMode {
  String get label {
    switch (this) {
      case TutorMode.academic:
        return '🎓 Academic Professor';
      case TutorMode.pyqStrategist:
        return '🎯 PYQ Strategist';
      case TutorMode.feynman:
        return '🧠 Feynman (ELI5)';
      case TutorMode.trapHunter:
        return '⚠️ Trap Hunter';
      case TutorMode.derivation:
        return '📐 Math & Steps';
      case TutorMode.socratic:
        return '⚖️ Socratic Coach';
    }
  }

  String get shortTag {
    switch (this) {
      case TutorMode.academic:
        return 'Professor';
      case TutorMode.pyqStrategist:
        return 'PYQ';
      case TutorMode.feynman:
        return 'Feynman';
      case TutorMode.trapHunter:
        return 'Traps';
      case TutorMode.derivation:
        return 'Steps';
      case TutorMode.socratic:
        return 'Socratic';
    }
  }

  String get id {
    switch (this) {
      case TutorMode.academic:
        return 'academic';
      case TutorMode.pyqStrategist:
        return 'pyq';
      case TutorMode.feynman:
        return 'feynman';
      case TutorMode.trapHunter:
        return 'traps';
      case TutorMode.derivation:
        return 'derivation';
      case TutorMode.socratic:
        return 'socratic';
    }
  }
}

class AiModelOption {
  final String providerId; // 'google', 'openai', 'anthropic'
  final String providerName; // 'Google Gemini', 'OpenAI ChatGPT', 'Anthropic / DeepSeek'
  final String modelId;
  final String modelName;
  final String description;
  final String iconEmoji;

  const AiModelOption({
    required this.providerId,
    required this.providerName,
    required this.modelId,
    required this.modelName,
    required this.description,
    required this.iconEmoji,
  });
}

class AiTutorController extends ChangeNotifier {
  final AiTutorRepository _repository = AiTutorRepository();

  static const List<AiModelOption> availableModels = [
    // 1. Google Gemini Top Models
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini 3',
      modelId: 'gemini-3.5-flash-lite',
      modelName: 'Gemini 3.5 Flash-Lite',
      description: '⚡ Fast responses for everyday doubts (Default)',
      iconEmoji: '🚀',
    ),
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini 3',
      modelId: 'gemini-3.7-flash',
      modelName: 'Gemini 3.7 Flash',
      description: '🧠 Reliable multi-step execution',
      iconEmoji: '🧠',
    ),
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini 3',
      modelId: 'gemini-3.6-flash',
      modelName: 'Gemini 3.6 Flash',
      description: '⚙️ Reliable multi-step execution',
      iconEmoji: '⚙️',
    ),
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini 3',
      modelId: 'gemini-3.8-flash',
      modelName: 'Gemini 3.8 Flash',
      description: '🧠 Higher reasoning for complex questions',
      iconEmoji: '🧠',
    ),
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini 3',
      modelId: 'gemini-3.1-pro-preview',
      modelName: 'Gemini 3.1 Pro (Preview)',
      description: '🏆 Advanced multimodal (text + image + audio)',
      iconEmoji: '🏆',
    ),

    // Google Production Tier Models
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini',
      modelId: 'gemini-2.5-flash',
      modelName: 'Gemini 2.5 Flash',
      description: '💡 Next-gen high speed reasoning',
      iconEmoji: '💡',
    ),
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini',
      modelId: 'gemini-2.0-flash',
      modelName: 'Gemini 2.0 Flash',
      description: '⚡ Ultra-fast multimodal',
      iconEmoji: '⚡',
    ),
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini',
      modelId: 'gemini-1.5-pro',
      modelName: 'Gemini 1.5 Pro',
      description: '📚 Massive 2M context window',
      iconEmoji: '📚',
    ),
    AiModelOption(
      providerId: 'google',
      providerName: 'Google Gemini',
      modelId: 'gemini-1.5-flash',
      modelName: 'Gemini 1.5 Flash',
      description: '⚡ Efficient high-volume processing',
      iconEmoji: '⚡',
    ),

    // 2. OpenAI ChatGPT Provider
    AiModelOption(
      providerId: 'openai',
      providerName: 'OpenAI ChatGPT',
      modelId: 'gpt-4o',
      modelName: 'GPT-4o',
      description: '🌟 Omnimodal powerhouse for complex tasks',
      iconEmoji: '🌟',
    ),
    AiModelOption(
      providerId: 'openai',
      providerName: 'OpenAI ChatGPT',
      modelId: 'gpt-4o-mini',
      modelName: 'GPT-4o Mini',
      description: '⚡ Lightweight & responsive',
      iconEmoji: '⚡',
    ),

    // 3. Anthropic Claude Provider
    AiModelOption(
      providerId: 'anthropic',
      providerName: 'Anthropic Claude',
      modelId: 'claude-3-7-sonnet',
      modelName: 'Claude 3.7 Sonnet',
      description: '🎨 Hybrid reasoning & expressive depth',
      iconEmoji: '🎨',
    ),

    // 4. DeepSeek AI Provider
    AiModelOption(
      providerId: 'deepseek',
      providerName: 'DeepSeek AI',
      modelId: 'deepseek-r1',
      modelName: 'DeepSeek R1',
      description: '🧩 Deep reasoning & open-weight math solving',
      iconEmoji: '🧩',
    ),
  ];

  late AiModelOption _selectedModel;
  TutorMode _tutorMode = TutorMode.academic;
  final List<ChatMessageModel> _messages = [];
  List<ChatSessionModel> _sessions = [];
  ChatSessionModel? _currentSession;
  bool _isLoadingSessions = false;

  List<ChatSessionModel> get sessions => _sessions;
  ChatSessionModel? get currentSession => _currentSession;
  String? get currentSessionId => _currentSession?.id;
  String get currentSessionTitle => _currentSession?.title ?? 'New Chat';
  bool get isLoadingSessions => _isLoadingSessions;
  bool _isLoading = false;
  bool _isStreaming = false;
  CancelToken? _activeRequestCancelToken;
  String? _editingMessageId;
  String? _selectedImagePath;
  String? _selectedImageBase64;
  String? _errorMessage;

  String? _activeNoteTitle;
  String? _activeNoteContext;

  AiModelOption get selectedModel => _selectedModel;
  TutorMode get tutorMode => _tutorMode;
  TutorMode get selectedTutorMode => _tutorMode;
  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  String? get editingMessageId => _editingMessageId;
  bool get isSocraticMode => _tutorMode == TutorMode.socratic;
  String? get selectedImagePath => _selectedImagePath;
  String? get selectedImageBase64 => _selectedImageBase64;
  String? get errorMessage => _errorMessage;
  String? get activeNoteTitle => _activeNoteTitle;
  String? get activeNoteContext => _activeNoteContext;

  bool canEditLastQuestion(String messageId) {
    if (_isLoading) return false;
    for (var index = _messages.length - 1; index >= 0; index--) {
      final message = _messages[index];
      if (!message.isUser) continue;
      return message.id == messageId && (message.imageUrl == null || message.imageUrl!.isEmpty);
    }
    return false;
  }

  bool canRegenerateAnswer(String assistantMessageId) {
    if (_isLoading || _messages.isEmpty || _messages.last.id != assistantMessageId) return false;
    for (var index = _messages.length - 2; index >= 0; index--) {
      final message = _messages[index];
      if (!message.isUser) continue;
      return message.imageUrl == null || message.imageUrl!.isEmpty;
    }
    return false;
  }

  void beginEditingLastQuestion(String messageId) {
    if (canEditLastQuestion(messageId)) {
      _editingMessageId = messageId;
      notifyListeners();
    }
  }

  void cancelEditingMessage() {
    if (_editingMessageId != null) {
      _editingMessageId = null;
      notifyListeners();
    }
  }

  Future<void> regenerateLastAnswer(String assistantMessageId) async {
    if (!canRegenerateAnswer(assistantMessageId)) return;
    final assistantIndex = _messages.length - 1;
    var userIndex = assistantIndex - 1;
    while (userIndex >= 0 && !_messages[userIndex].isUser) {
      userIndex--;
    }
    if (userIndex < 0) return;

    final question = _messages[userIndex];
    await sendQuestion(question.content, reuseUserMessageId: question.id);
  }

  AiTutorController() {
    _loadSavedModel();
    loadSessions();
  }

  void _loadSavedModel() {
    try {
      final savedModelId = HiveStorage.boxSyncMeta.get('user_selected_ai_model_id') as String?;
      if (savedModelId != null) {
        final match = availableModels.firstWhere(
          (m) => m.modelId == savedModelId,
          orElse: () => availableModels.first,
        );
        _selectedModel = match;
        return;
      }
    } catch (_) {}
    _selectedModel = availableModels.first;
  }

  Future<void> selectModel(AiModelOption model) async {
    _selectedModel = model;
    notifyListeners();

    try {
      await HiveStorage.boxSyncMeta.put('user_selected_ai_model_id', model.modelId);
      await HiveStorage.boxSyncMeta.put('user_selected_ai_provider_id', model.providerId);
    } catch (_) {}
  }

  void setTutorMode(TutorMode mode) {
    _tutorMode = mode;
    notifyListeners();
  }

  void switchModeByName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('feynman') || lower.contains('eli5')) {
      setTutorMode(TutorMode.feynman);
    } else if (lower.contains('pyq') || lower.contains('exam')) {
      setTutorMode(TutorMode.pyqStrategist);
    } else if (lower.contains('trap')) {
      setTutorMode(TutorMode.trapHunter);
    } else if (lower.contains('step') || lower.contains('deriv')) {
      setTutorMode(TutorMode.derivation);
    } else if (lower.contains('socratic')) {
      setTutorMode(TutorMode.socratic);
    } else {
      setTutorMode(TutorMode.academic);
    }
  }

  void toggleSocraticMode() {
    if (_tutorMode == TutorMode.socratic) {
      _tutorMode = TutorMode.academic;
    } else {
      _tutorMode = TutorMode.socratic;
    }
    notifyListeners();
  }

  void setNoteContext(String title, String context) {
    _activeNoteTitle = title;
    _activeNoteContext = context;
    notifyListeners();
  }

  void setImageAttachment(String? path, String? base64) {
    _selectedImagePath = path;
    _selectedImageBase64 = base64;
    notifyListeners();
  }

  void clearImageAttachment() {
    _selectedImagePath = null;
    _selectedImageBase64 = null;
    notifyListeners();
  }

  // --- ChatGPT-Style Session Management ---

  Future<void> loadSessions() async {
    _isLoadingSessions = true;
    notifyListeners();

    try {
      final fetched = await _repository.getChatSessions();
      _sessions = fetched;
    } catch (_) {} finally {
      _isLoadingSessions = false;
      notifyListeners();
    }
  }

  Future<void> selectSession(ChatSessionModel session) async {
    _editingMessageId = null;
    _currentSession = session;
    _isLoading = true;
    notifyListeners();

    try {
      final msgs = await _repository.getSessionMessages(session.id);
      _messages.clear();
      _messages.addAll(msgs);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startNewChat() {
    _currentSession = null;
    _editingMessageId = null;
    _messages.clear();
    _activeNoteTitle = null;
    _activeNoteContext = null;
    clearImageAttachment();
    notifyListeners();
  }

  Future<void> renameSession(String sessionId, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    final success = await _repository.updateChatSession(sessionId, trimmed);
    if (success) {
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        _sessions[index] = _sessions[index].copyWith(title: trimmed);
      }
      if (_currentSession?.id == sessionId) {
        _currentSession = _currentSession!.copyWith(title: trimmed);
      }
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final success = await _repository.deleteChatSession(sessionId);
    if (success) {
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_currentSession?.id == sessionId) {
        startNewChat();
      } else {
        notifyListeners();
      }
    }
  }

  Future<bool> deleteChatTurn(String messageId) async {
    if (_isLoading) return false;

    final targetIndex = _messages.indexWhere((message) => message.id == messageId);
    if (targetIndex == -1) return false;

    final target = _messages[targetIndex];
    var questionIndex = target.isUser ? targetIndex : -1;
    var answerIndex = target.isAssistant ? targetIndex : -1;

    if (target.isUser) {
      for (var index = targetIndex + 1; index < _messages.length; index++) {
        if (_messages[index].isUser) break;
        if (_messages[index].isAssistant) {
          answerIndex = index;
          break;
        }
      }
    } else if (target.isAssistant) {
      for (var index = targetIndex - 1; index >= 0; index--) {
        if (_messages[index].isUser) {
          questionIndex = index;
          break;
        }
      }
    }

    final sessionId = _currentSession?.id ?? target.sessionId;
    final persistedMessageId = answerIndex == -1 ? target.id : _messages[answerIndex].id;
    if (sessionId != null && sessionId.isNotEmpty) {
      final deleted = await _repository.deleteChatTurn(sessionId, persistedMessageId);
      if (!deleted) return false;
    }

    final startIndex = questionIndex == -1 ? targetIndex : questionIndex;
    final endIndex = answerIndex == -1 ? targetIndex : answerIndex;
    _messages.removeRange(startIndex, endIndex + 1);

    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        messageCount: _messages.length,
        lastMessage: _messages.isEmpty ? '' : _messages.last.content,
      );
      final sessionIndex = _sessions.indexWhere((session) => session.id == _currentSession!.id);
      if (sessionIndex != -1) _sessions[sessionIndex] = _currentSession!;
    }

    notifyListeners();
    if (sessionId != null && sessionId.isNotEmpty) await loadSessions();
    return true;
  }

  Future<void> loadHistory({String scopeType = 'global', String? scopeId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final history = await _repository.getChatHistory(
        scopeType: scopeType,
        scopeId: scopeId,
      );
      _messages.clear();
      _messages.addAll(history);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendVoiceDoubt(String audioPath) async {
    _isLoading = true;
    _errorMessage = null;

    final userMsg = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: '🎤 Spoken Voice Doubt',
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);
    notifyListeners();

    try {
      String audioBase64 = '';
      if (kIsWeb) {
        if (audioPath.startsWith('data:')) {
          audioBase64 = audioPath.split(',').last;
        }
      } else {
        final file = File(audioPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          audioBase64 = base64Encode(bytes);
        }
      }

      final botResponse = await _repository.askDoubt(
        question: 'Voice Question: Please listen to the attached audio recording and answer my doubt thoroughly',
        scopeType: 'global',
        audioBase64: audioBase64,
        audioMimeType: 'audio/m4a',
        contextNotes: _activeNoteContext == null || _activeNoteContext!.isEmpty
            ? ''
            : '[ATTACHED NOTE CONTEXT]\n$_activeNoteContext',
        provider: _selectedModel.providerId,
        model: _selectedModel.modelId,
        mode: _tutorMode.id,
      );

      _messages.add(botResponse);
    } catch (e) {
      final errorMessage = ApiClient.handleError(e);
      _errorMessage = errorMessage;
      _messages.add(
        ChatMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: 'Sorry, I could not process the voice note: $errorMessage',
          createdAt: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendQuestion(
    String question, {
    String scopeType = 'chat',
    String? scopeId,
    String? reuseUserMessageId,
  }) async {
    if (question.trim().isEmpty && _selectedImageBase64 == null) return;

    final editMessageId = _editingMessageId;
    final existingUserMessageId = reuseUserMessageId ?? editMessageId;
    final existingUserIndex = existingUserMessageId == null
        ? -1
        : _messages.indexWhere((message) => message.id == existingUserMessageId && message.isUser);
    if (existingUserMessageId != null && existingUserIndex == -1) return;

    final isEditingLastQuestion = editMessageId != null && existingUserMessageId == editMessageId;
    final isRegeneratingLastAnswer = reuseUserMessageId != null && !isEditingLastQuestion;
    final existingUserMessage = existingUserIndex == -1 ? null : _messages[existingUserIndex];
    final previousTurn = existingUserIndex == -1 ? <ChatMessageModel>[] : _messages.sublist(existingUserIndex);
    final effectiveSessionId = _currentSession?.id ?? existingUserMessage?.sessionId ?? scopeId;
    final requestCancelToken = CancelToken();
    _activeRequestCancelToken = requestCancelToken;
    _isStreaming = true;
    final userMessageId = existingUserMessageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    final userMsg = ChatMessageModel(
      id: userMessageId,
      role: 'user',
      content: question.trim(),
      imageUrl: existingUserMessage?.imageUrl ?? _selectedImagePath,
      sessionId: effectiveSessionId,
      createdAt: existingUserMessage?.createdAt ?? DateTime.now(),
    );

    if (existingUserIndex == -1) {
      _messages.add(userMsg);
    } else {
      _messages[existingUserIndex] = userMsg;
      _messages.removeRange(existingUserIndex + 1, _messages.length);
    }
    _editingMessageId = null;
    _isLoading = true;
    _errorMessage = null;

    final imageBase64ToSend = existingUserIndex == -1 ? _selectedImageBase64 : null;
    final previousMessages = _messages.length > 1 ? _messages.sublist(0, _messages.indexWhere((message) => message.id == userMessageId)) : <ChatMessageModel>[];
    final recentMessages = previousMessages.length > 8 ? previousMessages.sublist(previousMessages.length - 8) : previousMessages;
    final conversationHistory = recentMessages
      .where((message) => (message.role == 'user' || message.role == 'assistant') && message.content.trim().isNotEmpty)
      .map((message) => {'role': message.role, 'content': message.content})
      .toList();
    clearImageAttachment();
    notifyListeners();

    try {
      final botResponse = await _repository.askDoubt(
        question: question,
        scopeType: 'chat',
        scopeId: effectiveSessionId,
        sessionId: effectiveSessionId,
        imageBase64: imageBase64ToSend,
        cancelToken: requestCancelToken,
        contextNotes: _activeNoteContext == null || _activeNoteContext!.isEmpty
            ? ''
            : '[ATTACHED NOTE CONTEXT]\n$_activeNoteContext',
        conversationHistory: conversationHistory,
        provider: _selectedModel.providerId,
        regenerateLastAnswer: isRegeneratingLastAnswer,
        editLastQuestion: isEditingLastQuestion,
        model: _selectedModel.modelId,
        mode: _tutorMode.id,
      );

      if (_messages.any((message) => message.id == userMessageId)) {
        _messages.add(botResponse);
      }

      // Manage Session in UI (like ChatGPT)
      final returnedSessionId = botResponse.sessionId ?? effectiveSessionId;
      if (returnedSessionId != null && returnedSessionId.isNotEmpty) {
        if (_currentSession == null) {
          final title = question.trim().length > 40
              ? '${question.trim().substring(0, 40)}...'
              : question.trim();
          final newSession = ChatSessionModel(
            id: returnedSessionId,
            title: title.isEmpty ? 'New Conversation' : title,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            messageCount: _messages.length,
            lastMessage: botResponse.content,
          );
          _currentSession = newSession;
          _sessions.insert(0, newSession);
        } else {
          final index = _sessions.indexWhere((s) => s.id == _currentSession!.id);
          final updated = _currentSession!.copyWith(
            updatedAt: DateTime.now(),
            messageCount: _messages.length,
            lastMessage: botResponse.content,
          );
          _currentSession = updated;
          if (index != -1) {
            _sessions.removeAt(index);
            _sessions.insert(0, updated);
          }
        }
      }
    } catch (e) {
      if (existingUserMessageId != null && previousTurn.isNotEmpty) {
        final currentTurnIndex = _messages.indexWhere((message) => message.id == existingUserMessageId);
        if (currentTurnIndex != -1) {
          _messages.removeRange(currentTurnIndex, _messages.length);
          _messages.addAll(previousTurn);
          notifyListeners();
        }
      }
      if (!requestCancelToken.isCancelled) {
        final errorMessage = ApiClient.handleError(e);
        _errorMessage = errorMessage;
        _messages.add(
          ChatMessageModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: 'assistant',
            content: errorMessage,
            followUpQuestions: question.trim().isNotEmpty ? [question.trim()] : const [],
            createdAt: DateTime.now(),
          ),
        );
      }
    } finally {
      if (identical(_activeRequestCancelToken, requestCancelToken)) {
        _activeRequestCancelToken = null;
      }
      _isStreaming = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void stopGeneration() {
    final cancelToken = _activeRequestCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Stopped by user');
    }
  }

  void clearChat() {
    _editingMessageId = null;
    _messages.clear();
    notifyListeners();
  }
}
