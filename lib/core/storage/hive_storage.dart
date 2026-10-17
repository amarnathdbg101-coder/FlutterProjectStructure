import 'package:hive_flutter/hive_flutter.dart';

/// HiveStorage manages offline-first persistent caching for mobile study sessions.
class HiveStorage {
  static const String boxCoursesName = 'courses_cache';
  static const String boxFoldersName = 'folders_cache';
  static const String boxNotesName = 'notes_cache';
  static const String boxQuizzesName = 'quizzes_cache';
  static const String boxMindMapsName = 'mind_maps_cache';
  static const String boxFormulasName = 'formulas_cache';
  static const String boxFlashcardsName = 'flashcards_cache';
  static const String boxSyncMetaName = 'sync_meta';

  static late Box boxCourses;
  static late Box boxFolders;
  static late Box boxNotes;
  static late Box boxQuizzes;
  static late Box boxMindMaps;
  static late Box boxFormulas;
  static late Box boxFlashcards;
  static late Box boxSyncMeta;

  static Future<void> init() async {
    await Hive.initFlutter();
    boxCourses = await Hive.openBox(boxCoursesName);
    boxFolders = await Hive.openBox(boxFoldersName);
    boxNotes = await Hive.openBox(boxNotesName);
    boxQuizzes = await Hive.openBox(boxQuizzesName);
    boxMindMaps = await Hive.openBox(boxMindMapsName);
    boxFormulas = await Hive.openBox(boxFormulasName);
    boxFlashcards = await Hive.openBox(boxFlashcardsName);
    boxSyncMeta = await Hive.openBox(boxSyncMetaName);
  }

  // Last Sync Timestamp
  static String? getLastSyncTime() {
    return boxSyncMeta.get('last_synced_at') as String?;
  }

  static Future<void> setLastSyncTime(String timestamp) async {
    await boxSyncMeta.put('last_synced_at', timestamp);
  }

  // Course Caching
  static List<Map<String, dynamic>> getCachedCourses() {
    return boxCourses.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> cacheCourses(List<Map<String, dynamic>> courses) async {
    for (var c in courses) {
      if (c['id'] != null) {
        await boxCourses.put(c['id'], c);
      }
    }
  }

  // Folder Caching
  static List<Map<String, dynamic>> getCachedFolders(String courseId) {
    return boxFolders.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((f) => f['course_id'] == courseId)
        .toList();
  }

  static Future<void> cacheFolders(List<Map<String, dynamic>> folders) async {
    for (var f in folders) {
      if (f['id'] != null) {
        await boxFolders.put(f['id'], f);
      }
    }
  }

  // Notes Caching
  static List<Map<String, dynamic>> getCachedNotes({String? courseId, String? folderId}) {
    var notes = boxNotes.values.map((e) => Map<String, dynamic>.from(e as Map));
    if (courseId != null) {
      notes = notes.where((n) => n['course_id'] == courseId);
    }
    if (folderId != null) {
      notes = notes.where((n) => n['folder_id'] == folderId);
    }
    return notes.toList();
  }

  static Future<void> cacheNotes(List<Map<String, dynamic>> notes) async {
    for (var n in notes) {
      if (n['id'] != null) {
        await boxNotes.put(n['id'], n);
      }
    }
  }

  // --- Mind Map Caching (0ms instant offline load) ---
  static Map<String, dynamic>? getCachedMindMap(String id) {
    final raw = boxMindMaps.get(id);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> cacheMindMap(String id, Map<String, dynamic> data) async {
    await boxMindMaps.put(id, data);
  }

  static List<Map<String, dynamic>> getCachedMindMapList() {
    final raw = boxMindMaps.get('saved_mind_maps_list');
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  static Future<void> cacheMindMapList(List<Map<String, dynamic>> list) async {
    await boxMindMaps.put('saved_mind_maps_list', list);
  }

  // --- Formula Sheets Caching ---
  static String? getCachedFormulaSheet(String topic) {
    return boxFormulas.get('sheet_$topic') as String?;
  }

  static Future<void> cacheFormulaSheet(String topic, String markdownContent) async {
    await boxFormulas.put('sheet_$topic', markdownContent);
  }

  // --- Flashcard Decks Caching ---
  static List<Map<String, dynamic>> getCachedFlashcardDecks() {
    return boxFlashcards.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> cacheFlashcardDeck(String deckId, Map<String, dynamic> deckData) async {
    await boxFlashcards.put(deckId, deckData);
  }

  // Clear all caches on logout
  static Future<void> clearAll() async {
    await boxCourses.clear();
    await boxFolders.clear();
    await boxNotes.clear();
    await boxQuizzes.clear();
    await boxMindMaps.clear();
    await boxFormulas.clear();
    await boxFlashcards.clear();
    await boxSyncMeta.clear();
  }
}
