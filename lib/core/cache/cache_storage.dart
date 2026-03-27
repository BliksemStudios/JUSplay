import 'dart:convert';

import 'package:hive/hive.dart';

import 'cache_metadata.dart';

/// Hive-backed metadata storage for the song cache.
class CacheStorage {
  static const String _boxName = 'cache_metadata';

  late final Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  CacheMetadata? getCached(String songId) {
    final json = _box.get(songId);
    if (json == null) return null;
    return CacheMetadata.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  Future<void> setCached(CacheMetadata metadata) async {
    await _box.put(metadata.songId, jsonEncode(metadata.toJson()));
  }

  Future<void> removeCached(String songId) async {
    await _box.delete(songId);
  }

  List<CacheMetadata> getAllCached() {
    return _box.values.map((json) {
      return CacheMetadata.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    }).toList();
  }

  int getTotalCacheSize() {
    var total = 0;
    for (final json in _box.values) {
      final map = jsonDecode(json) as Map<String, dynamic>;
      total += (map['fileSize'] as int?) ?? 0;
    }
    return total;
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
