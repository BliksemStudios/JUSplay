import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/settings_storage.dart';
import 'cache_metadata.dart';
import 'cache_storage.dart';

/// Manages downloading and caching of songs for offline playback.
///
/// Songs are stored as files in the app's documents directory under
/// `music_cache/`. Metadata (file size, access times) is tracked in a
/// Hive box via [CacheStorage].
///
/// Eviction is LRU-based: when the cache exceeds the user-configured
/// size limit, least-recently-accessed files are removed first.
class CacheManager {
  final CacheStorage _storage;
  final SettingsStorage _settings;
  final Dio _dio;
  late final Directory _cacheDir;

  CacheManager({
    required CacheStorage storage,
    required SettingsStorage settings,
    required Dio dio,
  })  : _storage = storage,
        _settings = settings,
        _dio = dio;

  Future<void> init() async {
    await _storage.init();
    final docs = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${docs.path}/music_cache');
    if (!_cacheDir.existsSync()) {
      _cacheDir.createSync(recursive: true);
    }
  }

  /// Returns the local file for [songId] if cached, or `null`.
  File? getCachedFile(String songId) {
    final metadata = _storage.getCached(songId);
    if (metadata == null) return null;

    final file = File(metadata.filePath);
    if (file.existsSync()) {
      metadata.lastAccessedAt = DateTime.now();
      _storage.setCached(metadata);
      return file;
    }

    // File was deleted externally — clean up metadata.
    _storage.removeCached(songId);
    return null;
  }

  /// Returns `true` if [songId] has a cached local file.
  bool isCached(String songId) {
    final metadata = _storage.getCached(songId);
    if (metadata == null) return false;
    return File(metadata.filePath).existsSync();
  }

  /// Downloads a song and stores it locally. Returns the cached [File].
  ///
  /// If the song is already cached, returns the existing file immediately.
  /// [streamUrl] is the full authenticated Subsonic stream URL.
  Future<File> download(
    String songId,
    String streamUrl, {
    int quality = 0,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final existing = getCachedFile(songId);
    if (existing != null) return existing;

    await _enforceMaxSize();

    final file = File('${_cacheDir.path}/$songId');

    await _dio.download(
      streamUrl,
      file.path,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
    );

    final fileSize = await file.length();

    await _storage.setCached(CacheMetadata(
      songId: songId,
      filePath: file.path,
      fileSize: fileSize,
      cachedAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
      quality: quality,
    ));

    return file;
  }

  /// Removes a specific cached song.
  Future<void> removeCached(String songId) async {
    final metadata = _storage.getCached(songId);
    if (metadata != null) {
      final file = File(metadata.filePath);
      if (file.existsSync()) file.deleteSync();
      await _storage.removeCached(songId);
    }
  }

  /// Clears all cached files and metadata.
  Future<void> clearCache() async {
    if (_cacheDir.existsSync()) {
      for (final entity in _cacheDir.listSync()) {
        if (entity is File) entity.deleteSync();
      }
    }
    await _storage.clearAll();
  }

  /// Current cache size in megabytes.
  int get cacheSizeMB => _storage.getTotalCacheSize() ~/ (1024 * 1024);

  /// Set of all currently cached song IDs.
  Set<String> get cachedSongIds {
    return _storage.getAllCached().map((m) => m.songId).toSet();
  }

  /// Returns a stream URL that prefers the local file if cached.
  ///
  /// If the song is cached locally, returns a `file://` URI.
  /// Otherwise returns the original [streamUrl] for streaming.
  String resolveStreamUrl(String songId, String streamUrl) {
    final cached = getCachedFile(songId);
    if (cached != null) return cached.uri.toString();
    return streamUrl;
  }

  /// Evicts LRU entries until the cache is within limits.
  Future<void> _enforceMaxSize() async {
    final maxBytes = _settings.cacheSize * 1024 * 1024;
    final currentSize = _storage.getTotalCacheSize();

    if (currentSize < maxBytes) return;

    final all = _storage.getAllCached()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));

    var freed = 0;
    for (final metadata in all) {
      if (currentSize - freed <= maxBytes * 0.8) break;

      final file = File(metadata.filePath);
      if (file.existsSync()) {
        freed += metadata.fileSize;
        file.deleteSync();
      }
      await _storage.removeCached(metadata.songId);
    }
  }
}
