import 'dart:math';

import 'package:flutter/services.dart';

import '../api/subsonic_api.dart';
import '../audio/audio_player_service.dart';
import '../models/models.dart';

/// Bridges CarPlay native UI requests to the Subsonic API and audio handler.
///
/// The native CarPlay scene delegate calls these methods via a Flutter method
/// channel to browse the library and trigger playback.
class CarPlayService {
  static const _channel = MethodChannel('com.bliksemstudios.jusplay/carplay');

  final SubsonicApi _api;
  final AudioPlayerHandler _audioHandler;

  // Cached song lists keyed by "source:sourceId" for playback.
  final Map<String, List<Song>> _songCache = {};

  CarPlayService({
    required SubsonicApi api,
    required AudioPlayerHandler audioHandler,
  })  : _api = api,
        _audioHandler = audioHandler {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getArtists':
        return _getArtists();
      case 'getArtistAlbums':
        final id = call.arguments['id'] as String;
        return _getArtistAlbums(id);
      case 'getAlbums':
        final type = call.arguments['type'] as String;
        final limit = call.arguments['limit'] as int? ?? 50;
        return _getAlbums(type, limit);
      case 'getAlbumSongs':
        final id = call.arguments['id'] as String;
        return _getAlbumSongs(id);
      case 'getPlaylists':
        return _getPlaylists();
      case 'getPlaylistSongs':
        final id = call.arguments['id'] as String;
        return _getPlaylistSongs(id);
      case 'getFavourites':
        return _getFavourites();
      case 'getSongs':
        return _getSongs();
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
  // Browsing
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _getArtists() async {
    final artists = await _api.getArtists();
    return artists.map((a) => {
      'id': a.id,
      'name': a.name,
      'albumCount': a.albumCount,
      'coverArtUrl': a.coverArtId != null
          ? _api.coverArtUrl(a.coverArtId, size: 200)
          : null,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getArtistAlbums(String artistId) async {
    final albums = await _api.getArtistAlbums(artistId);
    return albums.map((a) => {
      'id': a.id,
      'name': a.name,
      'artist': a.artistName,
      'year': a.year,
      'coverArtUrl': a.coverArtId != null
          ? _api.coverArtUrl(a.coverArtId, size: 200)
          : null,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getAlbums(String type, int limit) async {
    final albums = await _api.getAlbumList(type: type, size: limit);
    return albums.map((a) => {
      'id': a.id,
      'name': a.name,
      'artist': a.artistName,
      'year': a.year,
      'coverArtUrl': a.coverArtId != null
          ? _api.coverArtUrl(a.coverArtId, size: 200)
          : null,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getAlbumSongs(String albumId) async {
    final songs = await _api.getAlbumSongs(albumId);
    _songCache['album:$albumId'] = songs;
    return _songsToMaps(songs);
  }

  Future<List<Map<String, dynamic>>> _getPlaylists() async {
    final playlists = await _api.getPlaylists();
    return playlists.map((p) => {
      'id': p.id,
      'name': p.name,
      'songCount': p.songCount,
      'coverArtUrl': p.coverArtId != null
          ? _api.coverArtUrl(p.coverArtId, size: 200)
          : null,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getPlaylistSongs(String playlistId) async {
    final playlist = await _api.getPlaylist(playlistId);
    final songs = playlist.songs;
    _songCache['playlist:$playlistId'] = songs;
    return _songsToMaps(songs);
  }

  Future<List<Map<String, dynamic>>> _getFavourites() async {
    final songs = await _api.getStarred();
    _songCache['favourites:'] = songs;
    return _songsToMaps(songs);
  }

  Future<List<Map<String, dynamic>>> _getSongs() async {
    final result = await _api.search('', songCount: 500);
    _songCache['songs:all'] = result.songs;
    return _songsToMaps(result.songs);
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
      // Re-fetch from server
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
        case 'songs':
          final result = await _api.search('', songCount: 500);
          songs = result.songs;
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
  // Helpers
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _songsToMaps(List<Song> songs) {
    return songs.map((s) => {
      'id': s.id,
      'title': s.title,
      'artist': s.artist ?? '',
      'album': s.album ?? '',
      'duration': s.duration,
      'coverArtUrl': s.coverArtId != null
          ? _api.coverArtUrl(s.coverArtId, size: 200)
          : null,
    }).toList();
  }
}
