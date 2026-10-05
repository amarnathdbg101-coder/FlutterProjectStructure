import '../services/api_key_vault_service.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';

class AiTutorRepository {
  final Dio _dio = ApiClient().dio;

  Future<ChatMessageModel> askDoubt({
    required String question,
    String scopeType = 'chat',
    String? scopeId,
    String? sessionId,
    String? imageBase64,
    String? imageMimeType,
    String? audioBase64,
    String? audioMimeType,
    String? contextNotes,
    List<Map<String, String>>? conversationHistory,
    String? provider,
    String? model,
    String? mode,
    String? targetExam,
    String? academicLevel,
    List<String>? weakTopics,
  }) async {
    final effectiveSessionId = sessionId ?? (scopeType == 'chat' || scopeType == 'session' ? scopeId : null);

    final keyVault = ApiKeyVaultService();
    await keyVault.loadVault();
    final customKey = keyVault.activeApiKey;

    final response = await _dio.post(
      ApiConstants.aiDoubt,
      data: {
        'question': question,
        'scope_type': scopeType,
        'scope_id': effectiveSessionId ?? scopeId ?? '',
        if (effectiveSessionId != null && effectiveSessionId.isNotEmpty) 'session_id': effectiveSessionId,
        'image_base64': imageBase64 ?? '',
        'image_mime_type': imageMimeType ?? 'image/jpeg',
        if (audioBase64 != null && audioBase64.isNotEmpty) 'audio_base64': audioBase64,
        if (audioMimeType != null && audioMimeType.isNotEmpty) 'audio_mime_type': audioMimeType,
        'context_notes': contextNotes ?? '',
        if (conversationHistory != null && conversationHistory.isNotEmpty) 'conversation_history': conversationHistory,
        'provider': provider ?? 'google',
        'model': model ?? 'gemini-3.5-flash-lite',
        'mode': mode ?? 'academic',
        if (targetExam != null && targetExam.isNotEmpty) 'target_exam': targetExam,
        if (academicLevel != null && academicLevel.isNotEmpty) 'academic_level': academicLevel,
        if (weakTopics != null && weakTopics.isNotEmpty) 'weak_topics': weakTopics,
        if (customKey.isNotEmpty) 'api_key': customKey,
      },
      options: Options(
        headers: {
          if (customKey.isNotEmpty) 'X-Gemini-API-Key': customKey,
        },
      ),
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      final data = response.data['data'] as Map<String, dynamic>;
      final solution = data['solution_markdown'] as String? ?? '';
      final returnedSessionId = data['session_id'] as String? ?? effectiveSessionId;

      List<String> chips = [];
      if (data['follow_up_chips'] is List) {
        chips = (data['follow_up_chips'] as List).map((e) => e.toString()).toList();
      }

      return ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: solution,
        followUpQuestions: chips,
        createdAt: DateTime.now(),
        sessionId: returnedSessionId,
      );
    }
    throw Exception('Failed to get answer from AI Tutor');
  }

  // --- Multi-Session ChatGPT-Style History APIs ---

  Future<List<ChatSessionModel>> getChatSessions() async {
    try {
      final response = await _dio.get(ApiConstants.aiSessions);
      if (response.statusCode == 200 && response.data['data'] != null) {
        final list = (response.data['data'] as List)
            .map((item) => ChatSessionModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return list;
      }
    } catch (_) {
      // In case user is guest or endpoint is not reachable
    }
    return [];
  }

  Future<ChatSessionModel?> createChatSession(String title) async {
    try {
      final response = await _dio.post(
        ApiConstants.aiSessions,
        data: {'title': title},
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        return ChatSessionModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
      }
    } catch (_) {}
    return null;
  }

  Future<List<ChatMessageModel>> getSessionMessages(String sessionId) async {
    try {
      final response = await _dio.get('${ApiConstants.aiSessions}/$sessionId');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final list = (response.data['data'] as List)
            .map((item) => ChatMessageModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<bool> updateChatSession(String sessionId, String newTitle) async {
    try {
      final response = await _dio.patch(
        '${ApiConstants.aiSessions}/$sessionId',
        data: {'title': newTitle},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteChatSession(String sessionId) async {
    try {
      final response = await _dio.delete('${ApiConstants.aiSessions}/$sessionId');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<ChatMessageModel>> getChatHistory({
    String scopeType = 'global',
    String? scopeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'scope_type': scopeType,
      };
      if (scopeId != null && scopeId.isNotEmpty) {
        queryParams['scope_id'] = scopeId;
      }

      final response = await _dio.get(
        ApiConstants.aiHistory,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final list = (response.data['data'] as List)
            .map((item) => ChatMessageModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return list;
      }
    } catch (_) {}
    return [];
  }
}
