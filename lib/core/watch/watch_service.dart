import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';

import '../api/subsonic_api.dart';
import '../audio/audio_player_service.dart';
import '../models/models.dart';

/// Bridges watchOS companion app requests to the Subsonic API and audio handler.
///
/// The iPhone-side WatchSessionManager forwards messages from the Apple Watch
/// via a Flutter method channel. This service mirrors the CarPlay pattern.
class WatchService {
  static const _channel = MethodChannel('com.bliksemstudios.jusplay/watch');

  final SubsonicApi _api;
  final AudioPlayerHandler _audioHandler;
  final Server _server;

  // Cached song lists keyed by "source:sourceId" for playback.
  final Map<String, List<Song>> _songCache = {};

  Timer? _playbackTimer;

  WatchService({
    required SubsonicApi api,
    required AudioPlayerHandler audioHandler,
    required Server server,
  })  : _api = api,
        _audioHandler = audioHandler,
        _server = server {
    _channel.setMethodCallHandler(_handleMethodCall);
    _startPlaybackStateUpdates();
    _syncServerToWatch();
  }

  /// Pushes the active server config to the Watch via the native bridge.
  void _syncServerToWatch() {
    try {
      _channel.invokeMethod('syncServerConfig', {
        'url': _server.url,
        'username': _server.username,
        'password': _server.password,
        'token': _server.token,
        'salt': _server.salt,
        'name': _server.name,
      });
    } catch (_) {
      // Native side may not be ready yet.
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _playbackTimer?.cancel();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getNowPlaying':
        return _getNowPlaying();
      case 'playPause':
        return _playPause();
      case 'skipNext':
        return _skipNext();
      case 'skipPrev':
        return _skipPrev();
      case 'seekTo':
        final position = call.arguments['position'] as double;
        return _seekTo(position);
      case 'getPlaylists':
        return _getPlaylists();
      case 'getPlaylistSongs':
        final id = call.arguments['id'] as String;
        return _getPlaylistSongs(id);
      case 'getRecentAlbums':
        return _getRecentAlbums();
      case 'getAlbumSongs':
        final id = call.arguments['id'] as String;
        return _getAlbumSongs(id);
      case 'getFavourites':
        return _getFavourites();
      case 'playSongs':
        final source = call.arguments['source'] as String;
        final sourceId = call.arguments['sourceId'] as String;
        final startIndex = call.arguments['startIndex'] as int? ?? 0;
        final shuffle = call.arguments['shuffle'] as bool? ?? false;
        return _playSongs(source, sourceId, startIndex, shuffle);
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Now Playing
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _getNowPlaying() {
    final queue = _audioHandler.songQueue;
    final index = _audioHandler.currentIndex;
    if (queue.isEmpty || index < 0 || index >= queue.length) return null;

    final song = queue[index];
    final player = _audioHandler.player;

    return {
      'id': song.id,
      'title': song.title,
      'artist': song.artist ?? '',
      'album': song.album ?? '',
      'duration': song.duration.toDouble(),
      'position': player.position.inMilliseconds / 1000.0,
      'isPlaying': player.playing,
      'coverArtUrl': song.coverArtId != null
          ? _api.coverArtUrl(song.coverArtId, size: 300)
          : null,
    };
  }

  // ---------------------------------------------------------------------------
  // Playback Controls
  // ---------------------------------------------------------------------------

  Future<void> _playPause() async {
    if (_audioHandler.player.playing) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> _skipNext() async {
    await _audioHandler.skipToNext();
  }

  Future<void> _skipPrev() async {
    await _audioHandler.skipToPrevious();
  }

  Future<void> _seekTo(double positionSeconds) async {
    await _audioHandler.seek(
      Duration(milliseconds: (positionSeconds * 1000).toInt()),
    );
  }

  // ---------------------------------------------------------------------------
  // Browsing
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _getRecentAlbums() async {
    final albums = await _api.getAlbumList(type: 'recent', size: 25);
    return albums
        .map((a) => {
              'id': a.id,
              'name': a.name,
              'artist': a.artistName,
              'coverArtUrl': a.coverArtId != null
                  ? _api.coverArtUrl(a.coverArtId, size: 200)
                  : null,
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getPlaylists() async {
    final playlists = await _api.getPlaylists();
    return playlists
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'songCount': p.songCount,
              'coverArtUrl': p.coverArtId != null
                  ? _api.coverArtUrl(p.coverArtId, size: 200)
                  : null,
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getPlaylistSongs(
      String playlistId) async {
    final playlist = await _api.getPlaylist(playlistId);
    final songs = playlist.songs;
    _songCache['playlist:$playlistId'] = songs;
    return _songsToMaps(songs);
  }

  Future<List<Map<String, dynamic>>> _getAlbumSongs(String albumId) async {
    final songs = await _api.getAlbumSongs(albumId);
    _songCache['album:$albumId'] = songs;
    return _songsToMaps(songs);
  }

  Future<List<Map<String, dynamic>>> _getFavourites() async {
    final songs = await _api.getStarred();
    _songCache['favourites:'] = songs;
    return _songsToMaps(songs);
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<void> _playSongs(
    String source,
    String sourceId,
    int startIndex,
    bool shuffle,
  ) async {
    List<Song> songs;
    final cached = _songCache['$source:$sourceId'];

    if (cached != null && cached.isNotEmpty) {
      songs = cached;
    } else {
      switch (source) {
        case 'album':
          songs = await _api.getAlbumSongs(sourceId);
          break;
        case 'playlist':
          final playlist = await _api.getPlaylist(sourceId);
          songs = playlist.songs;
          break;
        case 'favourites':
          songs = await _api.getStarred();
          break;
        default:
          return;
      }
      _songCache['$source:$sourceId'] = songs;
    }

    if (songs.isEmpty) return;

    if (shuffle) {
      songs = List.of(songs)..shuffle(Random());
      startIndex = 0;
    }

    await _audioHandler.playQueue(
      songs,
      startIndex: startIndex,
      getStreamUrl: (songId) => _api.streamUrl(songId),
      getCoverArtUrl: (coverArtId) => _api.coverArtUrl(coverArtId, size: 600),
    );
  }

  // ---------------------------------------------------------------------------
  // Playback state push (iPhone -> Watch)
  // ---------------------------------------------------------------------------

  /// Periodically pushes playback state to the native side so the
  /// WatchSessionManager can forward it to the Watch via WCSession.
  void _startPlaybackStateUpdates() {
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pushPlaybackState();
    });

    // Also push immediately when current index changes.
    _audioHandler.player.currentIndexStream.listen((_) {
      _pushPlaybackState();
    });

    // Push when playing state changes.
    _audioHandler.player.playingStream.listen((_) {
      _pushPlaybackState();
    });
  }

  void _pushPlaybackState() {
    final state = _getNowPlaying();
    try {
      _channel.invokeMethod('playbackStateChanged', state);
    } catch (_) {
      // Native side may not be listening yet.
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _songsToMaps(List<Song> songs) {
    return songs
        .map((s) => {
              'id': s.id,
              'title': s.title,
              'artist': s.artist ?? '',
              'album': s.album ?? '',
              'duration': s.duration,
              'coverArtUrl': s.coverArtId != null
                  ? _api.coverArtUrl(s.coverArtId, size: 200)
                  : null,
            })
        .toList();
  }
}
