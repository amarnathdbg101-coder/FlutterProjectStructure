import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_key_vault_service.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/ai_language_service.dart';
import '../../../core/storage/token_storage.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';
import '../services/ai_stream_transport.dart' as web_stream;

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
    void Function(String chunk)? onChunk,
    CancelToken? cancelToken,
    bool regenerateLastAnswer = false,
    bool editLastQuestion = false,
    String? provider,
    String? model,
    String? mode,
    String? targetExam,
    String? academicLevel,
    String? customInstructions,
    List<String>? weakTopics,
  }) async {
    final effectiveSessionId = sessionId ?? (scopeType == 'chat' || scopeType == 'session' ? scopeId : null);

    final keyVault = ApiKeyVaultService();
    await keyVault.loadVault();
    final customKey = keyVault.activeApiKey;

    final selectedLang = AILanguageService.getSelectedLanguageSync();

    final requestData = <String, dynamic>{
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
      if (regenerateLastAnswer) 'regenerate_last_answer': true,
      if (editLastQuestion) 'edit_last_question': true,
      'provider': provider ?? 'google',
      'model': model ?? 'gemini-3.5-flash-lite',
      'mode': mode ?? 'academic',
      if (targetExam != null && targetExam.isNotEmpty) 'target_exam': targetExam,
      if (academicLevel != null && academicLevel.isNotEmpty) 'academic_level': academicLevel,
      if (customInstructions != null && customInstructions.isNotEmpty) 'custom_instructions': customInstructions,
      if (weakTopics != null && weakTopics.isNotEmpty) 'weak_topics': weakTopics,
      if (customKey.isNotEmpty) 'api_key': customKey,
      if (selectedLang.isNotEmpty) 'ai_language': selectedLang,
      if (selectedLang.isNotEmpty) 'language': selectedLang,
    };
    final headers = <String, String>{
      if (customKey.isNotEmpty) 'X-Gemini-API-Key': customKey,
      if (selectedLang.isNotEmpty) 'X-AI-Language': selectedLang,
    };

    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await _sendDoubtRequest(
          requestData: requestData,
          headers: headers,
          effectiveSessionId: effectiveSessionId,
          onChunk: onChunk,
          cancelToken: cancelToken,
        );
      } catch (e) {
        final isColdStart = (e is DioException &&
                (e.response?.statusCode == 502 ||
                    e.response?.statusCode == 503 ||
                    e.response?.statusCode == 504)) ||
            (e.toString().contains('502') || e.toString().contains('503'));

        if (isColdStart && attempts < 2 && (cancelToken == null || !cancelToken.isCancelled)) {
          // Wait 4 seconds for Render server container to finish starting up, then retry
          await Future.delayed(const Duration(milliseconds: 4000));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<ChatMessageModel> _sendDoubtRequest({
    required Map<String, dynamic> requestData,
    required Map<String, String> headers,
    required String? effectiveSessionId,
    required void Function(String chunk)? onChunk,
    required CancelToken? cancelToken,
  }) async {
    if (onChunk != null) {
      final content = StringBuffer();
      final followUpQuestions = <String>[];
      String? returnedSessionId = effectiveSessionId;
      String? returnedAssistantMessageId;
      String? returnedUserMessageImageUrl;
      String? returnedSpokenTranscript;
      List<AiBlockModel>? returnedBlocks;
      String? streamError;
      var pendingSseText = '';

      void processSseLine(String line) {
        if (!line.startsWith('data:')) return;
        final raw = line.substring(5).trim();
        if (raw.isEmpty || raw == '[DONE]') return;

        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) return;

          switch (decoded['type']) {
            case 'chunk':
              final chunk = decoded['text']?.toString() ?? '';
              if (chunk.isNotEmpty) {
                content.write(chunk);
                onChunk(chunk);
              }
            case 'done':
              returnedSessionId = decoded['session_id'] as String? ?? returnedSessionId;
              returnedAssistantMessageId = decoded['assistant_message_id'] as String?;
              returnedUserMessageImageUrl = decoded['user_message_image_url'] as String?;
              returnedSpokenTranscript = decoded['spoken_transcript'] as String?;
              if (decoded['blocks'] is List) {
                returnedBlocks = (decoded['blocks'] as List)
                    .whereType<Map<String, dynamic>>()
                    .map(AiBlockModel.fromJson)
                    .toList();
              }
              if (decoded['follow_up_chips'] is List) {
                followUpQuestions.addAll((decoded['follow_up_chips'] as List).map((item) => item.toString()));
              }
            case 'error':
              streamError = decoded['message']?.toString() ?? 'AI response stream failed';
          }
        } catch (_) {
          // Ignore invalid or non-JSON payloads safely
        }
      }

      void processSseText(String text) {
        pendingSseText += text;
        var newlineIndex = pendingSseText.indexOf('\n');
        while (newlineIndex != -1) {
          var line = pendingSseText.substring(0, newlineIndex);
          if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
          processSseLine(line);
          pendingSseText = pendingSseText.substring(newlineIndex + 1);
          newlineIndex = pendingSseText.indexOf('\n');
        }
      }

      ChatMessageModel buildStreamMessage() {
        if (streamError != null && content.isEmpty) throw Exception(streamError);
        if (content.isEmpty) throw Exception('AI response stream ended without an answer');
        return ChatMessageModel(
          id: returnedAssistantMessageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: content.toString(),
          imageUrl: returnedUserMessageImageUrl,
          followUpQuestions: followUpQuestions,
          createdAt: DateTime.now(),
          sessionId: returnedSessionId,
          spokenTranscript: returnedSpokenTranscript,
          blocks: returnedBlocks,
        );
      }

      if (kIsWeb) {
        await TokenStorage.init();
        final token = TokenStorage.getToken();
        final responseStatus = await web_stream.postSse(
          uri: Uri.parse('${ApiConstants.baseUrl}${ApiConstants.aiDoubtStream}'),
          body: jsonEncode(requestData),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
            ...headers,
          },
          onText: processSseText,
          cancelFuture: cancelToken?.whenCancel,
        );
        if (responseStatus != 404 && responseStatus != 405) {
          if (pendingSseText.isNotEmpty) processSseLine(pendingSseText);
          if (responseStatus < 200 || responseStatus >= 300) {
            if (content.isEmpty) {
              throw Exception('AI stream request failed with status $responseStatus');
            }
          }
          return buildStreamMessage();
        }
      } else {
        try {
          final streamedResponse = await _dio.post<ResponseBody>(
            ApiConstants.aiDoubtStream,
            data: requestData,
            options: Options(
              headers: headers,
              responseType: ResponseType.stream,
              receiveTimeout: const Duration(seconds: 90),
            ),
            cancelToken: cancelToken,
          );
          final stream = streamedResponse.data?.stream;
          if (stream == null) throw Exception('AI stream returned no response body');
          try {
            await for (final line in stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
              processSseLine(line);
            }
          } catch (_) {
            if (content.isEmpty) rethrow;
          }
          if (pendingSseText.isNotEmpty) processSseLine(pendingSseText);
          return buildStreamMessage();
        } on DioException catch (error) {
          if (content.isNotEmpty) {
            return buildStreamMessage();
          }
          if (error.response?.statusCode != 404 && error.response?.statusCode != 405) rethrow;
        }
      }
    }

    final response = await _dio.post(
      ApiConstants.aiDoubt,
      data: requestData,
      options: Options(
        headers: headers,
        receiveTimeout: const Duration(seconds: 90),
      ),
      cancelToken: cancelToken,
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      final data = response.data['data'] as Map<String, dynamic>;
      final solution = data['solution_markdown'] as String? ?? '';
      final returnedSessionId = data['session_id'] as String? ?? effectiveSessionId;
      if (onChunk != null && solution.isNotEmpty) onChunk(solution);

      List<String> chips = [];
      if (data['follow_up_chips'] is List) {
        chips = (data['follow_up_chips'] as List).map((e) => e.toString()).toList();
      }

      List<AiBlockModel>? blocks;
      if (data['blocks'] is List) {
        blocks = (data['blocks'] as List)
            .whereType<Map<String, dynamic>>()
            .map(AiBlockModel.fromJson)
            .toList();
      }

      return ChatMessageModel(
        id: data['assistant_message_id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: solution,
        imageUrl: data['user_message_image_url'] as String? ?? data['image_url'] as String?,
        followUpQuestions: chips,
        createdAt: DateTime.now(),
        sessionId: returnedSessionId,
        spokenTranscript: data['spoken_transcript'] as String?,
        blocks: blocks,
      );
    }

    throw Exception('Failed to get response from AI server');
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

  Future<bool> deleteChatTurn(String sessionId, String messageId) async {
    try {
      final response = await _dio.delete('${ApiConstants.aiSessions}/$sessionId/messages/$messageId');
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
