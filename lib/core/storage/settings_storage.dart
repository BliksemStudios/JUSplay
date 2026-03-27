import 'package:hive/hive.dart';

/// Hive-backed storage for application settings.
///
/// Uses a Hive box called `settings`. All getters return sensible defaults
/// when a value has not been explicitly set.
class SettingsStorage {
  static const String _boxName = 'settings';

  // ---------------------------------------------------------------------------
  // Keys
  // ---------------------------------------------------------------------------

  static const String _streamingQualityKey = 'streaming_quality';
  static const String _downloadQualityKey = 'download_quality';
  static const String _wifiOnlyKey = 'wifi_only';
  static const String _cacheSizeKey = 'cache_size';
  static const String _scrobblingEnabledKey = 'scrobbling_enabled';
  static const String _themeModeKey = 'theme_mode';
  static const String _gaplessPlaybackKey = 'gapless_playback';
  static const String _replayGainKey = 'replay_gain';
  static const String _accentThemeKey = 'accent_theme';
  static const String _geminiApiKeyKey = 'gemini_api_key';

  late final Box<dynamic> _box;

  /// Opens the settings Hive box. Must be called before any other method.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  // ---------------------------------------------------------------------------
  // Streaming quality (0 = raw / original, higher values = max bitrate in kbps)
  // ---------------------------------------------------------------------------

  int get streamingQuality =>
      _box.get(_streamingQualityKey, defaultValue: 0) as int;

  Future<void> setStreamingQuality(int value) =>
      _box.put(_streamingQualityKey, value);

  // ---------------------------------------------------------------------------
  // Download quality (same semantics as streaming quality)
  // ---------------------------------------------------------------------------

  int get downloadQuality =>
      _box.get(_downloadQualityKey, defaultValue: 0) as int;

  Future<void> setDownloadQuality(int value) =>
      _box.put(_downloadQualityKey, value);

  // ---------------------------------------------------------------------------
  // Wi-Fi only
  // ---------------------------------------------------------------------------

  bool get wifiOnly => _box.get(_wifiOnlyKey, defaultValue: false) as bool;

  Future<void> setWifiOnly(bool value) => _box.put(_wifiOnlyKey, value);

  // ---------------------------------------------------------------------------
  // Cache size (in MB)
  // ---------------------------------------------------------------------------

  int get cacheSize => _box.get(_cacheSizeKey, defaultValue: 500) as int;

  Future<void> setCacheSize(int value) => _box.put(_cacheSizeKey, value);

  // ---------------------------------------------------------------------------
  // Scrobbling
  // ---------------------------------------------------------------------------

  bool get scrobblingEnabled =>
      _box.get(_scrobblingEnabledKey, defaultValue: true) as bool;

  Future<void> setScrobblingEnabled(bool value) =>
      _box.put(_scrobblingEnabledKey, value);

  // ---------------------------------------------------------------------------
  // Theme mode (dark / light / system)
  // ---------------------------------------------------------------------------

  String get themeMode =>
      _box.get(_themeModeKey, defaultValue: 'system') as String;

  Future<void> setThemeMode(String value) => _box.put(_themeModeKey, value);

  // ---------------------------------------------------------------------------
  // Gapless playback
  // ---------------------------------------------------------------------------

  bool get gaplessPlayback =>
      _box.get(_gaplessPlaybackKey, defaultValue: true) as bool;

  Future<void> setGaplessPlayback(bool value) =>
      _box.put(_gaplessPlaybackKey, value);

  // ---------------------------------------------------------------------------
  // ReplayGain
  // ---------------------------------------------------------------------------

  bool get replayGain =>
      _box.get(_replayGainKey, defaultValue: false) as bool;

  Future<void> setReplayGain(bool value) => _box.put(_replayGainKey, value);

  // ---------------------------------------------------------------------------
  // Accent theme key (goldAmber / cyanTeal / coralOrange / oledWhite)
  // ---------------------------------------------------------------------------

  String get accentTheme =>
      _box.get(_accentThemeKey, defaultValue: 'goldAmber') as String;

  Future<void> setAccentTheme(String value) =>
      _box.put(_accentThemeKey, value);

  // ---------------------------------------------------------------------------
  // Gemini API key
  // ---------------------------------------------------------------------------

  String get geminiApiKey =>
      _box.get(_geminiApiKeyKey, defaultValue: '') as String;

  Future<void> setGeminiApiKey(String value) =>
      _box.put(_geminiApiKeyKey, value);
}
