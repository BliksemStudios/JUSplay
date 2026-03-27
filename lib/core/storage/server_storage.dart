import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/server.dart';

/// Hive-backed storage for Subsonic server configurations.
///
/// Servers are persisted as JSON maps in a box called `servers`.
/// The currently active server ID is stored in the `settings` box under
/// the key `active_server_id`.
class ServerStorage {
  static const String _serversBoxName = 'servers';
  static const String _settingsBoxName = 'settings';
  static const String _activeServerKey = 'active_server_id';

  late final Box<String> _serversBox;
  late final Box<dynamic> _settingsBox;

  /// Opens the required Hive boxes. Must be called before any other method.
  Future<void> init() async {
    _serversBox = await Hive.openBox<String>(_serversBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  /// Returns all saved servers.
  Future<List<Server>> getServers() async {
    final servers = <Server>[];
    for (final key in _serversBox.keys) {
      final json = _serversBox.get(key);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        servers.add(Server.fromJson(map));
      }
    }
    return servers;
  }

  /// Persists a server configuration. Overwrites any existing entry with
  /// the same [Server.id].
  Future<void> saveServer(Server server) async {
    final json = jsonEncode(server.toJson());
    await _serversBox.put(server.id, json);
  }

  /// Deletes the server with the given [id].
  ///
  /// If the deleted server was the active server, the active server reference
  /// is also cleared.
  Future<void> deleteServer(String id) async {
    await _serversBox.delete(id);
    final activeId = _settingsBox.get(_activeServerKey) as String?;
    if (activeId == id) {
      await _settingsBox.delete(_activeServerKey);
    }
  }

  /// Returns the currently active server, or `null` if none is set.
  Future<Server?> getActiveServer() async {
    final activeId = _settingsBox.get(_activeServerKey) as String?;
    if (activeId == null) return null;

    final json = _serversBox.get(activeId);
    if (json == null) return null;

    final map = jsonDecode(json) as Map<String, dynamic>;
    return Server.fromJson(map);
  }

  /// Sets the active server by [id].
  Future<void> setActiveServer(String id) async {
    await _settingsBox.put(_activeServerKey, id);
  }
}
