import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_player_service.dart';

/// Holds the [AudioPlayerHandler] singleton that is initialised in `main.dart`
/// via [AudioService.init] before [runApp] is called.
///
/// Usage in main.dart:
/// ```dart
/// final audioHandler = await AudioService.init(
///   builder: () => AudioPlayerHandler(),
///   config: const AudioServiceConfig(
///     androidNotificationChannelId: 'com.bliksemstudios.jusplay.audio',
///     androidNotificationChannelName: 'JUSPlay',
///     androidNotificationOngoing: true,
///   ),
/// );
/// runApp(
///   ProviderScope(
///     overrides: [
///       audioHandlerProvider.overrideWithValue(audioHandler as AudioPlayerHandler),
///     ],
///     child: const JUSPlayApp(),
///   ),
/// );
/// ```
final audioHandlerProvider = Provider<AudioPlayerHandler>(
  (ref) => throw UnimplementedError(
    'audioHandlerProvider must be overridden with the AudioPlayerHandler '
    'instance created by AudioService.init() in main.dart.',
  ),
);

/// Streams the currently playing [MediaItem] (song metadata for lock screen
/// and notification display).
final currentSongProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem;
});

/// Streams the current [PlaybackState] (playing, paused, buffering, etc.).
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});

/// Streams the current queue as a list of [MediaItem]s.
final queueProvider = StreamProvider<List<MediaItem>>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.queue;
});

/// Streams the current playback position.
final positionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.positionStream;
});

/// Streams the total duration of the current track.
///
/// Emits `null` when no track is loaded.
final durationProvider = StreamProvider<Duration?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.durationStream;
});
