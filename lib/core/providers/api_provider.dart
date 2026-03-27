import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../cache/cache.dart';
import '../models/models.dart';
import '../storage/storage.dart';

// -----------------------------------------------------------------------------
// Storage providers
// -----------------------------------------------------------------------------

/// Provides the singleton [ServerStorage] instance.
///
/// The storage must be initialised (via [ServerStorage.init]) before the
/// provider container is created — typically in `main()`.
final serverStorageProvider = Provider<ServerStorage>((ref) {
  throw UnimplementedError(
    'serverStorageProvider must be overridden with an initialised instance.',
  );
});

/// Provides the singleton [SettingsStorage] instance.
///
/// The storage must be initialised (via [SettingsStorage.init]) before the
/// provider container is created — typically in `main()`.
final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  throw UnimplementedError(
    'settingsStorageProvider must be overridden with an initialised instance.',
  );
});

// -----------------------------------------------------------------------------
// Active server
// -----------------------------------------------------------------------------

/// Manages the currently active [Server].
///
/// On construction the notifier loads the persisted active server from storage.
/// Use [setServer] to switch servers and [clear] to deselect.
class ActiveServerNotifier extends StateNotifier<Server?> {
  ActiveServerNotifier(this._storage) : super(null) {
    loadActiveServer();
  }

  final ServerStorage _storage;

  /// Loads the active server from persistent storage.
  Future<void> loadActiveServer() async {
    state = await _storage.getActiveServer();
  }

  /// Sets [server] as the active server and persists the choice.
  Future<void> setServer(Server server) async {
    await _storage.setActiveServer(server.id);
    state = server;
  }

  /// Clears the active server selection.
  void clear() {
    state = null;
  }
}

/// Provides the currently active [Server] (or `null` if none selected).
final activeServerProvider =
    StateNotifierProvider<ActiveServerNotifier, Server?>((ref) {
  final storage = ref.watch(serverStorageProvider);
  return ActiveServerNotifier(storage);
});

// -----------------------------------------------------------------------------
// Subsonic API
// -----------------------------------------------------------------------------

/// Provides a [SubsonicApi] client configured for the active server.
///
/// Returns `null` when no server is selected.
final subsonicApiProvider = Provider<SubsonicApi?>((ref) {
  final server = ref.watch(activeServerProvider);
  if (server == null) return null;
  return SubsonicApi(server);
});

// -----------------------------------------------------------------------------
// Cache manager
// -----------------------------------------------------------------------------

/// Provides the singleton [CacheManager] instance.
///
/// Must be initialised via [CacheManager.init] and overridden in `main.dart`.
final cacheManagerProvider = Provider<CacheManager>((ref) {
  throw UnimplementedError(
    'cacheManagerProvider must be overridden with an initialised instance.',
  );
});
