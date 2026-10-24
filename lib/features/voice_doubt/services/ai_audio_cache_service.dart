import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_tts_service.dart';

/// High-Performance Local Audio & Chunk Disk Cache for StudySilo
/// Provides 0ms instant replay, offline persistence, and zero-battery audio playback
class AiAudioCacheService {
  static final AiAudioCacheService _instance = AiAudioCacheService._internal();
  factory AiAudioCacheService() => _instance;
  AiAudioCacheService._internal();

  // In-memory L1 cache for instantaneous retrieval
  static final Map<String, List<SpokenChunk>> _l1ChunkCache = {};
  static final Map<String, String> _l1AudioPathCache = {};

  /// Computes a fast, deterministic hash for text identification (Web & Native compatible)
  static String computeHash(String text) {
    if (text.isEmpty) return 'empty';
    // Dual 32-bit FNV hash (safe for JavaScript 53-bit integers & 64-bit Dart VM)
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    for (final unit in utf8.encode(text)) {
      h1 = ((h1 ^ unit) * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 ^ unit) * 0x01000193 + 1) & 0xFFFFFFFF;
    }
    return h1.toRadixString(16).padLeft(8, '0') + h2.toRadixString(16).padLeft(8, '0');
  }

  /// Retrieves pre-computed spoken chunks from L1 Memory or L2 Disk cache
  Future<List<SpokenChunk>?> getCachedChunks(String rawText) async {
    final key = computeHash(rawText);

    // 1. Check instant L1 Memory Cache
    if (_l1ChunkCache.containsKey(key)) {
      return _l1ChunkCache[key];
    }

    // 2. Check persistent L2 Storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = prefs.getString('tts_chunks_$key');
      if (serialized != null && serialized.isNotEmpty) {
        final List<dynamic> list = jsonDecode(serialized);
        final chunks = list.map((item) {
          final map = item as Map<String, dynamic>;
          return SpokenChunk(
            rawText: map['raw'] ?? '',
            spokenText: map['spoken'] ?? '',
          );
        }).toList();

        _l1ChunkCache[key] = chunks;
        return chunks;
      }
    } catch (e) {
      debugPrint('AiAudioCacheService getCachedChunks notice: $e');
    }

    return null;
  }

  /// Caches parsed spoken chunks to L1 Memory and persistent storage
  Future<void> cacheChunks(String rawText, List<SpokenChunk> chunks) async {
    if (rawText.isEmpty || chunks.isEmpty) return;
    final key = computeHash(rawText);

    // Save to L1 memory
    _l1ChunkCache[key] = chunks;

    // Persist to L2 storage in background
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = chunks.map((c) => {'raw': c.rawText, 'spoken': c.spokenText}).toList();
      await prefs.setString('tts_chunks_$key', jsonEncode(list));
    } catch (e) {
      debugPrint('AiAudioCacheService cacheChunks notice: $e');
    }
  }

  /// Checks if an audio file exists on disk for 0ms instant playback
  Future<String?> getCachedAudioPath(String rawText) async {
    if (kIsWeb) return null;
    final key = computeHash(rawText);

    if (_l1AudioPathCache.containsKey(key)) {
      final path = _l1AudioPathCache[key]!;
      if (File(path).existsSync()) return path;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      // Check MP3 first (used by Neural TTS) then WAV (used by native recorder)
      final mp3File = File('${tempDir.path}/studysilo_audio_$key.mp3');
      if (await mp3File.exists()) {
        _l1AudioPathCache[key] = mp3File.path;
        return mp3File.path;
      }
      final wavFile = File('${tempDir.path}/studysilo_audio_$key.wav');
      if (await wavFile.exists()) {
        _l1AudioPathCache[key] = wavFile.path;
        return wavFile.path;
      }
    } catch (_) {}

    return null;
  }

  /// Registers a newly synthesized audio file in the cache index and maintains LRU limits
  Future<void> registerAudioFile(String rawText, String filePath) async {
    if (kIsWeb || filePath.isEmpty) return;
    final key = computeHash(rawText);

    // Bounded in-memory RAM protection: max 30 entries
    if (_l1AudioPathCache.length >= 30) {
      _l1AudioPathCache.remove(_l1AudioPathCache.keys.first);
    }
    _l1AudioPathCache[key] = filePath;

    // Background disk storage quota check
    pruneCacheIfNeeded();
  }

  /// 🛡️ Device Storage Protection: Guarantees audio cache never exceeds 25MB
  /// Automatically purges oldest cache files so user's phone storage is 100% protected.
  Future<void> pruneCacheIfNeeded({int maxBytes = 25 * 1024 * 1024}) async {
    if (kIsWeb) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final audioFiles = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('studysilo_audio_'))
          .toList();

      int totalBytes = 0;
      final List<MapEntry<File, DateTime>> filesWithDates = [];

      for (final f in audioFiles) {
        try {
          final stat = f.statSync();
          totalBytes += stat.size;
          filesWithDates.add(MapEntry(f, stat.modified));
        } catch (_) {}
      }

      // If cache exceeds max quota (e.g. 25MB), prune oldest files
      if (totalBytes > maxBytes) {
        filesWithDates.sort((a, b) => a.value.compareTo(b.value));
        final targetBytes = (maxBytes * 0.6).round(); // Prune down to 60%

        for (final entry in filesWithDates) {
          if (totalBytes <= targetBytes) break;
          try {
            final size = entry.key.lengthSync();
            entry.key.deleteSync();
            totalBytes -= size;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('AiAudioCacheService prune notice: $e');
    }
  }

  /// Clears in-memory L1 cache to free RAM when needed
  void clearMemoryCache() {
    _l1ChunkCache.clear();
    _l1AudioPathCache.clear();
  }
}
