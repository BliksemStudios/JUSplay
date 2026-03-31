import 'dart:io';

import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../audio/audio_provider.dart';
import '../cache/cache.dart';
import '../carplay/carplay_service.dart';
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
// CarPlay (iOS only)
// -----------------------------------------------------------------------------

/// Initialises the CarPlay method channel bridge when a server is active.
///
/// Automatically disposes the previous instance when the server changes.
final carplayServiceProvider = Provider<CarPlayService?>((ref) {
  if (!Platform.isIOS) return null;
  final api = ref.watch(subsonicApiProvider);
  final handler = ref.watch(audioHandlerProvider);
  if (api == null) return null;
  final service = CarPlayService(api: api, audioHandler: handler);
  ref.onDispose(service.dispose);
  return service;
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

// -----------------------------------------------------------------------------
// Accent theme
// -----------------------------------------------------------------------------

/// Persists and exposes the currently selected accent theme key.
class AccentThemeNotifier extends StateNotifier<String> {
  AccentThemeNotifier(this._settings) : super(_settings.accentTheme);

  final SettingsStorage _settings;

  static const Map<String, String?> _iconNames = {
    'goldAmber': null,        // primary icon — pass null to reset
    'cyanTeal': 'icon_cyan',
    'coralOrange': 'icon_coral',
    'oledWhite': 'icon_oled',
  };

  Future<void> setTheme(String key) async {
    await _settings.setAccentTheme(key);
    state = key;
    // Switch iOS app icon (no-op on Android)
    try {
      final supported = await FlutterDynamicIcon.supportsAlternateIcons;
      final iconName = _iconNames[key];
      print('[Icon] setTheme("$key") -> iconName="$iconName", supported=$supported');
      if (supported && _iconNames.containsKey(key)) {
        await FlutterDynamicIcon.setAlternateIconName(iconName);
        final current = await FlutterDynamicIcon.getAlternateIconName;
        print('[Icon] After set: current alternate icon = "$current"');
      }
    } catch (e) {
      print('[Icon] FAILED for key "$key": $e');
    }
  }
}

/// Provides the active accent theme key (e.g. 'goldAmber').
final accentThemeProvider =
    StateNotifierProvider<AccentThemeNotifier, String>((ref) {
  final settings = ref.watch(settingsStorageProvider);
  return AccentThemeNotifier(settings);
});

// -----------------------------------------------------------------------------
// Current router location (updated by router listener in Task 4)
// -----------------------------------------------------------------------------

/// Tracks the current GoRouter path so widgets outside the router tree
/// (e.g. the global MiniPlayer overlay) can react to navigation.
final currentLocationProvider = StateProvider<String>((ref) => '/');
