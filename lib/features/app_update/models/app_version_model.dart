/// Model representing app version information received from GoBackend OTA endpoints.
class AppVersionModel {
  final bool updateAvailable;
  final String latestVersion;
  final int latestCode;
  final int currentCode;
  final bool isForceUpdate;
  final String downloadUrl;
  final int fileSizeBytes;
  final List<String> releaseNotes;
  final int minSupportedVersionCode;

  const AppVersionModel({
    required this.updateAvailable,
    required this.latestVersion,
    required this.latestCode,
    required this.currentCode,
    required this.isForceUpdate,
    required this.downloadUrl,
    required this.fileSizeBytes,
    required this.releaseNotes,
    required this.minSupportedVersionCode,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      updateAvailable: json['update_available'] as bool? ?? false,
      latestVersion: json['latest_version'] as String? ?? '',
      latestCode: json['latest_code'] as int? ?? 0,
      currentCode: json['current_code'] as int? ?? 0,
      isForceUpdate: json['is_force_update'] as bool? ?? false,
      downloadUrl: json['download_url'] as String? ?? '',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      releaseNotes: (json['release_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      minSupportedVersionCode:
          json['min_supported_version_code'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'update_available': updateAvailable,
        'latest_version': latestVersion,
        'latest_code': latestCode,
        'current_code': currentCode,
        'is_force_update': isForceUpdate,
        'download_url': downloadUrl,
        'file_size_bytes': fileSizeBytes,
        'release_notes': releaseNotes,
        'min_supported_version_code': minSupportedVersionCode,
      };
}
