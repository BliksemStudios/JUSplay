import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

/// Repeat mode for the audio player.
enum RepeatMode { none, one, all }

/// The main audio handler that bridges [just_audio] with [audio_service].
///
/// Manages a playback queue of [Song] objects, converts them to [MediaItem]s
/// for lock screen / notification controls, and maps player state to
/// [PlaybackState] for external consumers.
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    children: [],
  );

  final List<Song> _queue = [];
  final List<MediaItem> _mediaItems = [];
  int _currentIndex = -1;
  RepeatMode _repeatMode = RepeatMode.none;
  bool _shuffleEnabled = false;

  /// The underlying [AudioPlayer] instance, exposed for position / duration
  /// streams that providers need to observe.
  AudioPlayer get player => _player;

  /// The current song queue.
  List<Song> get songQueue => List.unmodifiable(_queue);

  /// The current playback index in the queue.
  int get currentIndex => _currentIndex;

  /// Callbacks for resolving stream/cover URLs — needed for queue restoration.
  /// Set by the caller when playQueue() is invoked.
  String Function(String songId)? _getStreamUrl;
  String Function(String? coverArtId)? _getCoverArtUrl;

  AudioPlayerHandler() {
    _init();
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    // Forward just_audio player state into audio_service PlaybackState.
    _player.playbackEventStream.listen(_broadcastPlaybackState);

    // When the current index changes (e.g. gapless transition to next track),
    // update the current media item and persist state.
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _mediaItems.length) {
        _currentIndex = index;
        mediaItem.add(_mediaItems[index]);
        _saveQueueState();
      }
    });

    // When the player reaches the end of a track, handle repeat / advance.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handlePlaybackCompleted();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Public API – single song
  // ---------------------------------------------------------------------------

  /// Plays a single [song], replacing the current queue.
  Future<void> playSong(
    Song song, {
    required String streamUrl,
    required String coverArtUrl,
  }) async {
    _queue
      ..clear()
      ..add(song);

    final item = _songToMediaItem(song, streamUrl, coverArtUrl);
    _mediaItems
      ..clear()
      ..add(item);

    _currentIndex = 0;
    queue.add(List.unmodifiable(_mediaItems));
    mediaItem.add(item);

    await _playlist.clear();
    await _playlist.add(AudioSource.uri(Uri.parse(streamUrl), tag: item));
    await _player.setAudioSource(_playlist);
    await _player.play();
  }

  // ---------------------------------------------------------------------------
  // Public API – queue management
  // ---------------------------------------------------------------------------

  /// Replaces the queue with [songs] and begins playback at [startIndex].
  ///
  /// [getStreamUrl] and [getCoverArtUrl] are callbacks that resolve URLs for
  /// each song so the caller can inject server-specific auth parameters.
  Future<void> playQueue(
    List<Song> songs, {
    required int startIndex,
    required String Function(String songId) getStreamUrl,
    required String Function(String? coverArtId) getCoverArtUrl,
  }) async {
    // Store URL callbacks for queue restoration
    _getStreamUrl = getStreamUrl;
    _getCoverArtUrl = getCoverArtUrl;

    _queue
      ..clear()
      ..addAll(songs);

    _mediaItems.clear();
    final audioSources = <AudioSource>[];

    for (final song in songs) {
      final streamUrl = getStreamUrl(song.id);
      final coverArtUrl = getCoverArtUrl(song.coverArtId);
      final item = _songToMediaItem(song, streamUrl, coverArtUrl);
      _mediaItems.add(item);
      audioSources.add(AudioSource.uri(Uri.parse(streamUrl), tag: item));
    }

    _currentIndex = startIndex;
    queue.add(List.unmodifiable(_mediaItems));
    mediaItem.add(_mediaItems[startIndex]);

    await _playlist.clear();
    await _playlist.addAll(audioSources);
    await _player.setAudioSource(_playlist, initialIndex: startIndex);
    await _player.play();

    // Persist queue state for restoration after app kill
    _saveQueueState();
  }

  /// Appends a [song] to the end of the current queue.
  Future<void> addToQueue(
    Song song, {
    required String streamUrl,
    required String coverArtUrl,
  }) async {
    _queue.add(song);

    final item = _songToMediaItem(song, streamUrl, coverArtUrl);
    _mediaItems.add(item);

    await _playlist.add(AudioSource.uri(Uri.parse(streamUrl), tag: item));
    queue.add(List.unmodifiable(_mediaItems));
  }

  /// Removes the song at [index] from the queue.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    _queue.removeAt(index);
    _mediaItems.removeAt(index);
    _playlist.removeAt(index);

    // Adjust current index if needed.
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      // If the currently playing song was removed, let just_audio handle the
      // transition; just clamp the index.
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.isEmpty ? -1 : _queue.length - 1;
      }
    }

    queue.add(List.unmodifiable(_mediaItems));
    if (_currentIndex >= 0 && _currentIndex < _mediaItems.length) {
      mediaItem.add(_mediaItems[_currentIndex]);
    }
  }

  /// Moves the queue item at [oldIndex] to [newIndex].
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (oldIndex == newIndex) return;

    final song = _queue.removeAt(oldIndex);
    final item = _mediaItems.removeAt(oldIndex);
    _playlist.removeAt(oldIndex);

    _queue.insert(newIndex, song);
    _mediaItems.insert(newIndex, item);
    _playlist.insert(
      newIndex,
      AudioSource.uri(Uri.parse(item.id), tag: item),
    );

    // Update current index to follow the playing track.
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    queue.add(List.unmodifiable(_mediaItems));
  }

  // ---------------------------------------------------------------------------
  // Playback mode
  // ---------------------------------------------------------------------------

  /// Enables or disables shuffle mode.
  void setShuffle(bool enabled) {
    _shuffleEnabled = enabled;
    _player.setShuffleModeEnabled(enabled);
    // Re-broadcast so the UI sees the updated shuffle state immediately
    _broadcastPlaybackState(_player.playbackEvent);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    setShuffle(enabled);
  }

  /// Sets the repeat mode.
  void setRepeat(RepeatMode mode) {
    _repeatMode = mode;
    switch (mode) {
      case RepeatMode.none:
        _player.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.all:
        _player.setLoopMode(LoopMode.all);
        break;
    }
    // Re-broadcast so the UI sees the updated repeat state immediately
    _broadcastPlaybackState(_player.playbackEvent);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        setRepeat(RepeatMode.none);
        break;
      case AudioServiceRepeatMode.one:
        setRepeat(RepeatMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        setRepeat(RepeatMode.all);
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // BaseAudioHandler overrides
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    mediaItem.add(null);
    _queue.clear();
    _mediaItems.clear();
    _currentIndex = -1;
    _clearSavedQueueState();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queue.length - 1) {
      await _player.seekToNext();
    } else if (_repeatMode == RepeatMode.all) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // If more than 3 seconds into the song, restart it instead.
    if ((_player.position.inSeconds) > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      await _player.seekToPrevious();
    } else if (_repeatMode == RepeatMode.all) {
      await _player.seek(Duration.zero, index: _queue.length - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _player.seek(Duration.zero, index: index);
    mediaItem.add(_mediaItems[index]);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts a [Song] model to a [MediaItem] used by audio_service for
  /// lock screen / notification display.
  MediaItem _songToMediaItem(
    Song song,
    String streamUrl,
    String coverArtUrl,
  ) {
    return MediaItem(
      id: streamUrl,
      title: song.title,
      artist: song.artist ?? 'Unknown Artist',
      album: song.album ?? 'Unknown Album',
      duration: Duration(seconds: song.duration),
      artUri: coverArtUrl.isNotEmpty ? Uri.parse(coverArtUrl) : null,
      extras: {'songId': song.id},
    );
  }

  /// Maps [just_audio] playback events to an [audio_service] [PlaybackState].
  void _broadcastPlaybackState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
        shuffleMode: _shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _mapRepeatMode(_repeatMode),
      ),
    );
  }

  /// Handles behaviour when a track finishes playing.
  void _handlePlaybackCompleted() {
    // LoopMode.one and LoopMode.all are handled natively by just_audio, so
    // we only need to handle the "no repeat" case where we're at the end.
    if (_repeatMode == RepeatMode.none &&
        _currentIndex >= _queue.length - 1) {
      stop();
    }
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  AudioServiceRepeatMode _mapRepeatMode(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return AudioServiceRepeatMode.none;
      case RepeatMode.one:
        return AudioServiceRepeatMode.one;
      case RepeatMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  // ---------------------------------------------------------------------------
  // Queue state persistence
  // ---------------------------------------------------------------------------

  static const _queueKey = 'jusplay_saved_queue';
  static const _indexKey = 'jusplay_saved_index';
  static const _positionKey = 'jusplay_saved_position';
  static const _shuffleKey = 'jusplay_saved_shuffle';
  static const _repeatKey = 'jusplay_saved_repeat';

  /// Persists the current queue, index, position, shuffle and repeat state.
  Future<void> _saveQueueState() async {
    if (_queue.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((s) => s.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
      await prefs.setInt(_indexKey, _currentIndex);
      await prefs.setDouble(
        _positionKey,
        _player.position.inMilliseconds.toDouble(),
      );
      await prefs.setBool(_shuffleKey, _shuffleEnabled);
      await prefs.setString(_repeatKey, _repeatMode.name);
    } catch (e) {
      print('[AudioHandler] Failed to save queue state: $e');
    }
  }

  /// Clears persisted queue state (called on explicit stop).
  Future<void> _clearSavedQueueState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_indexKey);
      await prefs.remove(_positionKey);
      await prefs.remove(_shuffleKey);
      await prefs.remove(_repeatKey);
    } catch (_) {}
  }

  /// Checks for a saved queue and restores it without auto-playing.
  ///
  /// [getStreamUrl] and [getCoverArtUrl] must be provided by the caller
  /// so the handler can rebuild audio sources.
  Future<bool> restoreQueueState({
    required String Function(String songId) getStreamUrl,
    required String Function(String? coverArtId) getCoverArtUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      if (queueJson == null) return false;

      final decoded = jsonDecode(queueJson) as List;
      if (decoded.isEmpty) return false;

      final songs = decoded
          .map((j) => Song.fromJson(j as Map<String, dynamic>))
          .toList();
      final savedIndex = prefs.getInt(_indexKey) ?? 0;
      final savedPositionMs = prefs.getDouble(_positionKey) ?? 0;
      final savedShuffle = prefs.getBool(_shuffleKey) ?? false;
      final savedRepeatName = prefs.getString(_repeatKey) ?? 'none';

      // Store URL callbacks
      _getStreamUrl = getStreamUrl;
      _getCoverArtUrl = getCoverArtUrl;

      _queue
        ..clear()
        ..addAll(songs);

      _mediaItems.clear();
      final audioSources = <AudioSource>[];

      for (final song in songs) {
        final streamUrl = getStreamUrl(song.id);
        final coverArtUrl = getCoverArtUrl(song.coverArtId);
        final item = _songToMediaItem(song, streamUrl, coverArtUrl);
        _mediaItems.add(item);
        audioSources.add(AudioSource.uri(Uri.parse(streamUrl), tag: item));
      }

      final index = savedIndex.clamp(0, songs.length - 1);
      _currentIndex = index;
      queue.add(List.unmodifiable(_mediaItems));
      mediaItem.add(_mediaItems[index]);

      await _playlist.clear();
      await _playlist.addAll(audioSources);
      await _player.setAudioSource(
        _playlist,
        initialIndex: index,
        initialPosition: Duration(milliseconds: savedPositionMs.toInt()),
      );

      // Restore shuffle and repeat modes
      _shuffleEnabled = savedShuffle;
      _player.setShuffleModeEnabled(savedShuffle);

      final repeatMode = RepeatMode.values.firstWhere(
        (m) => m.name == savedRepeatName,
        orElse: () => RepeatMode.none,
      );
      setRepeat(repeatMode);

      // Don't auto-play — user will see the restored state and can tap play
      print('[AudioHandler] Restored queue: ${songs.length} songs, '
          'index=$index, position=${savedPositionMs.toInt()}ms');
      return true;
    } catch (e) {
      print('[AudioHandler] Failed to restore queue state: $e');
      return false;
    }
  }
}
