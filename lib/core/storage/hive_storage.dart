import 'package:hive_flutter/hive_flutter.dart';

/// HiveStorage manages offline-first persistent caching for mobile study sessions.
class HiveStorage {
  static const String boxCoursesName = 'courses_cache';
  static const String boxFoldersName = 'folders_cache';
  static const String boxNotesName = 'notes_cache';
  static const String boxQuizzesName = 'quizzes_cache';
  static const String boxSyncMetaName = 'sync_meta';

  static late Box boxCourses;
  static late Box boxFolders;
  static late Box boxNotes;
  static late Box boxQuizzes;
  static late Box boxSyncMeta;

  static Future<void> init() async {
    await Hive.initFlutter();
    boxCourses = await Hive.openBox(boxCoursesName);
    boxFolders = await Hive.openBox(boxFoldersName);
    boxNotes = await Hive.openBox(boxNotesName);
    boxQuizzes = await Hive.openBox(boxQuizzesName);
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

  // Clear all caches on logout
  static Future<void> clearAll() async {
    await boxCourses.clear();
    await boxFolders.clear();
    await boxNotes.clear();
    await boxQuizzes.clear();
    await boxSyncMeta.clear();
  }
}
