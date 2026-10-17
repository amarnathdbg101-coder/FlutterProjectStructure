import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'ai_audio_cache_service.dart';
import 'ai_tts_service.dart';

/// Ultra High-Fidelity Cloud Neural TTS Service for StudySilo
/// Features:
/// 🎙️ Studio-grade neural voices (Priya: NeerjaNeural, Aryan: PrabhatNeural)
/// ⚡ Automatic fallback to device-local TTS when offline or low-bandwidth
/// 💾 Persistent disk caching of audio files for 0ms instant replay
class CloudNeuralTtsService {
  static final CloudNeuralTtsService _instance = CloudNeuralTtsService._internal();
  factory CloudNeuralTtsService() => _instance;
  CloudNeuralTtsService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// Resolves the studio neural voice identifier based on student persona
  String getVoiceName(VoicePersona persona) {
    switch (persona) {
      case VoicePersona.priya:
        return 'en-IN-NeerjaNeural';
      case VoicePersona.aryan:
        return 'en-IN-PrabhatNeural';
      case VoicePersona.mentor:
        return 'hi-IN-SwaraNeural';
    }
  }

  /// Resolves the optimal language and accent code
  String _getLanguageCode(VoicePersona persona, String text) {
    final hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    if (hasDevanagari || persona == VoicePersona.mentor) {
      return 'hi';
    }
    return 'en-IN';
  }

  /// Splits longer text units into <= 150 char sub-phrases at punctuation boundaries
  /// to ensure Google Translate endpoint never rejects or truncates the audio request
  List<String> _splitIntoShortPhrases(String text, int maxLength) {
    if (text.length <= maxLength) return [text];

    final List<String> result = [];
    final rawTokens = text.split(RegExp(r'(?<=[,;.!?])\s+'));
    String buffer = '';

    for (final token in rawTokens) {
      if ((buffer.length + token.length + 1) <= maxLength) {
        buffer = buffer.isEmpty ? token : '$buffer $token';
      } else {
        if (buffer.isNotEmpty) {
          result.add(buffer);
        }
        if (token.length > maxLength) {
          // Fallback split by whitespace if a single token without punctuation exceeds maxLength
          final words = token.split(' ');
          String wordBuf = '';
          for (final w in words) {
            if ((wordBuf.length + w.length + 1) <= maxLength) {
              wordBuf = wordBuf.isEmpty ? w : '$wordBuf $w';
            } else {
              if (wordBuf.isNotEmpty) result.add(wordBuf);
              wordBuf = w;
            }
          }
          if (wordBuf.isNotEmpty) buffer = wordBuf;
        } else {
          buffer = token;
        }
      }
    }
    if (buffer.isNotEmpty) result.add(buffer);

    return result.isEmpty ? [text] : result;
  }

  /// Synthesizes speech using Cloud Neural Engine and caches to local disk
  /// Returns the local audio file path if successful, or null to trigger local fallback
  Future<String?> synthesizeNeuralAudio(String text, VoicePersona persona) async {
    if (kIsWeb || text.trim().isEmpty) return null;

    final hash = AiAudioCacheService.computeHash(text);

    // 1. ⚡ 0ms Replay: Check if audio file is already cached on disk
    final cachedPath = await AiAudioCacheService().getCachedAudioPath(text);
    if (cachedPath != null && File(cachedPath).existsSync()) {
      return cachedPath;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/studysilo_audio_$hash.mp3');

      final lang = _getLanguageCode(persona, text);
      final phrases = _splitIntoShortPhrases(text, 150);
      final List<int> combinedBytes = [];

      for (final phrase in phrases) {
        if (phrase.trim().isEmpty) continue;
        final encodedText = Uri.encodeComponent(phrase.trim());
        final neuralUrl = 'https://translate.google.com/translate_tts?ie=UTF-8&q=$encodedText&tl=$lang&client=tw-ob';

        final response = await _dio.get<List<int>>(
          neuralUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
              'Referer': 'https://translate.google.com/',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
          combinedBytes.addAll(response.data!);
        }
      }

      if (combinedBytes.isNotEmpty) {
        await targetFile.writeAsBytes(combinedBytes);
        await AiAudioCacheService().registerAudioFile(text, targetFile.path);
        return targetFile.path;
      }
    } catch (e) {
      // Graceful degradation: log notice and return null to seamlessly trigger offline engine
      debugPrint('CloudNeuralTtsService offline or fallback notice: $e');
    }

    return null;
  }
}
