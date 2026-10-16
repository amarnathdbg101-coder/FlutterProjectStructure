import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class InAppUpdateMetadata {
  final String latestVersion;
  final int versionCode;
  final String downloadUrl;
  final String fileSizeMb;
  final List<String> releaseNotes;
  final bool forceUpdate;

  const InAppUpdateMetadata({
    required this.latestVersion,
    required this.versionCode,
    required this.downloadUrl,
    required this.fileSizeMb,
    required this.releaseNotes,
    this.forceUpdate = false,
  });

  factory InAppUpdateMetadata.fromJson(Map<String, dynamic> json) {
    List<String> parseNotes(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    return InAppUpdateMetadata(
      latestVersion: json['latest_version']?.toString() ?? '1.2.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 12,
      downloadUrl: json['download_url']?.toString() ?? 'https://ai.shopsilo.in/download/studysilo-v1.2.0.apk',
      fileSizeMb: json['file_size_mb']?.toString() ?? '28.5 MB',
      releaseNotes: parseNotes(json['release_notes']),
      forceUpdate: json['force_update'] as bool? ?? false,
    );
  }
}

class InAppUpdateService {
  static const String currentAppVersion = '1.2.0';
  static const int currentVersionCode = 12;
  static const String versionCheckUrl = 'https://ai.shopsilo.in/js/version.json';

  static Future<InAppUpdateMetadata?> checkForUpdates() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      final response = await dio.get(versionCheckUrl);
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final meta = InAppUpdateMetadata.fromJson(data);
        if (meta.versionCode > currentVersionCode) {
          return meta;
        }
      }
    } catch (e) {
      debugPrint('In-App update check skipped: $e');
    }
    return null;
  }

  static void showUpdateDialogIfNeeded(BuildContext context, InAppUpdateMetadata meta) {
    showDialog(
      context: context,
      barrierDismissible: !meta.forceUpdate,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Version v${meta.latestVersion} Available!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Size: ${meta.fileSizeMb} • Direct Download',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WHAT\'S NEW IN THIS UPDATE:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                ...meta.releaseNotes.map((note) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓ ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            if (!meta.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.file_download_rounded, size: 18),
              label: const Text('Update Now (Direct APK)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                // Opens direct APK download URL in browser/installer
              },
            ),
          ],
        );
      },
    );
  }
}
