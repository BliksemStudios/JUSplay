/// Metadata for a cached song file.
class CacheMetadata {
  final String songId;
  final String filePath;
  final int fileSize;
  final DateTime cachedAt;
  DateTime lastAccessedAt;
  final int quality;

  CacheMetadata({
    required this.songId,
    required this.filePath,
    required this.fileSize,
    required this.cachedAt,
    required this.lastAccessedAt,
    required this.quality,
  });

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'filePath': filePath,
        'fileSize': fileSize,
        'cachedAt': cachedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'quality': quality,
      };

  factory CacheMetadata.fromJson(Map<String, dynamic> json) => CacheMetadata(
        songId: json['songId'] as String,
        filePath: json['filePath'] as String,
        fileSize: json['fileSize'] as int,
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
        quality: json['quality'] as int? ?? 0,
      );
}
