import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_exception.dart';

/// Client for the Subsonic REST API.
///
/// All endpoints use JSON responses and authenticate via token-based auth
/// parameters provided by the [Server] model.
class SubsonicApi {
  final Server _server;
  final Dio _dio;

  SubsonicApi(this._server)
      : _dio = Dio(
          BaseOptions(
            baseUrl: '${_server.url}/rest/',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  /// Visible for testing: allows injecting a custom [Dio] instance.
  SubsonicApi.withDio(this._server, this._dio);

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Merges the server auth params with any additional query parameters.
  Map<String, dynamic> _params([Map<String, dynamic>? extra]) {
    return {
      ..._server.authParams(),
      if (extra != null) ...extra,
    };
  }

  /// Performs a GET request and extracts the `subsonic-response` envelope.
  ///
  /// Throws [SubsonicApiException] if the response status is `failed`.
  Future<Map<String, dynamic>> _get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      endpoint,
      queryParameters: _params(queryParameters),
    );

    final data = response.data!;
    final subsonicResponse = data['subsonic-response'] as Map<String, dynamic>;

    if (subsonicResponse['status'] != 'ok') {
      final error = subsonicResponse['error'] as Map<String, dynamic>;
      throw SubsonicApiException.fromJson(error);
    }

    return subsonicResponse;
  }

  /// Builds a full URL for a given endpoint including auth params.
  ///
  /// Used for endpoints that return binary data (streaming, cover art) where
  /// we need a direct URL rather than an HTTP response.
  String _buildUrl(String endpoint, [Map<String, dynamic>? extra]) {
    final params = _params(extra);
    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    return '${_server.url}/rest/$endpoint?$queryString';
  }

  // ---------------------------------------------------------------------------
  // System
  // ---------------------------------------------------------------------------

  /// Tests the connection to the server.
  ///
  /// Returns `true` if the server responds with a successful ping.
  Future<bool> ping() async {
    try {
      await _get('ping.view');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Browsing
  // ---------------------------------------------------------------------------

  /// Returns all artists on the server.
  ///
  /// The Subsonic response nests artists under `artists.index[].artist[]`.
  Future<List<Artist>> getArtists() async {
    final data = await _get('getArtists.view');
    final artists = <Artist>[];
    final indexes = data['artists']?['index'] as List<dynamic>?;
    if (indexes != null) {
      for (final index in indexes) {
        final artistList =
            (index as Map<String, dynamic>)['artist'] as List<dynamic>?;
        if (artistList != null) {
          artists.addAll(
            artistList.map(
              (a) => Artist.fromJson(a as Map<String, dynamic>),
            ),
          );
        }
      }
    }
    return artists;
  }

  /// Returns details for a single artist, including their albums.
  Future<Artist> getArtist(String id) async {
    final data = await _get('getArtist.view', queryParameters: {'id': id});
    return Artist.fromJson(data['artist'] as Map<String, dynamic>);
  }

  /// Returns a list of albums matching the given [type].
  ///
  /// Supported types: `recent`, `frequent`, `random`, `starred`, `newest`,
  /// `alphabeticalByName`, `alphabeticalByArtist`, `byYear`, `byGenre`.
  Future<List<Album>> getAlbumList({
    required String type,
    int? size,
    int? offset,
  }) async {
    final data = await _get('getAlbumList2.view', queryParameters: {
      'type': type,
      if (size != null) 'size': size,
      if (offset != null) 'offset': offset,
    });
    final albumList =
        data['albumList2']?['album'] as List<dynamic>?;
    if (albumList == null) return [];
    return albumList
        .map((a) => Album.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Returns a single album with its songs.
  ///
  /// Songs are included in the `song` array of the response.
  Future<Album> getAlbum(String id) async {
    final data = await _get('getAlbum.view', queryParameters: {'id': id});
    return Album.fromJson(data['album'] as Map<String, dynamic>);
  }

  /// Returns details for a single song.
  Future<Song> getSong(String id) async {
    final data = await _get('getSong.view', queryParameters: {'id': id});
    return Song.fromJson(data['song'] as Map<String, dynamic>);
  }

  /// Returns a list of all genres.
  Future<List<Genre>> getGenres() async {
    final data = await _get('getGenres.view');
    final genreList = data['genres']?['genre'] as List<dynamic>?;
    if (genreList == null) return [];
    return genreList
        .map((g) => Genre.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Searches for artists, albums, and songs matching [query].
  Future<SearchResult> search(
    String query, {
    int artistCount = 20,
    int albumCount = 20,
    int songCount = 20,
  }) async {
    final data = await _get('search3.view', queryParameters: {
      'query': query,
      'artistCount': artistCount,
      'albumCount': albumCount,
      'songCount': songCount,
    });
    return SearchResult.fromJson(
      data['searchResult3'] as Map<String, dynamic>? ?? {},
    );
  }

  // ---------------------------------------------------------------------------
  // Media retrieval (URL builders, no HTTP call)
  // ---------------------------------------------------------------------------

  /// Builds a streaming URL for the given song [id].
  ///
  /// This does not make an HTTP request; it returns a URL that can be passed
  /// directly to an audio player.
  String streamUrl(String id, {int? maxBitRate, String? format}) {
    return _buildUrl('stream.view', {
      'id': id,
      if (maxBitRate != null) 'maxBitRate': maxBitRate,
      if (format != null) 'format': format,
    });
  }

  /// Builds a cover art URL for the given cover art [id].
  ///
  /// Returns an empty string if [id] is null.
  String coverArtUrl(String? id, {int? size}) {
    if (id == null) return '';
    return _buildUrl('getCoverArt.view', {
      'id': id,
      if (size != null) 'size': size,
    });
  }

  // ---------------------------------------------------------------------------
  // Playlists
  // ---------------------------------------------------------------------------

  /// Returns all playlists visible to the current user.
  Future<List<Playlist>> getPlaylists() async {
    final data = await _get('getPlaylists.view');
    final playlistList =
        data['playlists']?['playlist'] as List<dynamic>?;
    if (playlistList == null) return [];
    return playlistList
        .map((p) => Playlist.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Returns a single playlist with its songs.
  Future<Playlist> getPlaylist(String id) async {
    final data =
        await _get('getPlaylist.view', queryParameters: {'id': id});
    return Playlist.fromJson(data['playlist'] as Map<String, dynamic>);
  }

  /// Creates a new playlist.
  ///
  /// If [songIds] is provided, the songs are added to the playlist.
  Future<void> createPlaylist({
    required String name,
    List<String>? songIds,
  }) async {
    await _get('createPlaylist.view', queryParameters: {
      'name': name,
      if (songIds != null) 'songId': songIds,
    });
  }

  /// Deletes a playlist by [id].
  Future<void> deletePlaylist(String id) async {
    await _get('deletePlaylist.view', queryParameters: {'id': id});
  }

  /// Updates an existing playlist.
  ///
  /// [songIdsToAdd] appends songs; [songIndexesToRemove] removes songs by
  /// their zero-based index in the current playlist.
  Future<void> updatePlaylist({
    required String id,
    String? name,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    await _get('updatePlaylist.view', queryParameters: {
      'playlistId': id,
      if (name != null) 'name': name,
      if (songIdsToAdd != null) 'songIdToAdd': songIdsToAdd,
      if (songIndexesToRemove != null)
        'songIndexToRemove': songIndexesToRemove,
    });
  }

  // ---------------------------------------------------------------------------
  // Starring / Favorites
  // ---------------------------------------------------------------------------

  /// Stars (favorites) an item. Provide exactly one of the IDs.
  Future<void> star({String? id, String? albumId, String? artistId}) async {
    await _get('star.view', queryParameters: {
      if (id != null) 'id': id,
      if (albumId != null) 'albumId': albumId,
      if (artistId != null) 'artistId': artistId,
    });
  }

  /// Removes a star from an item. Provide exactly one of the IDs.
  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    await _get('unstar.view', queryParameters: {
      if (id != null) 'id': id,
      if (albumId != null) 'albumId': albumId,
      if (artistId != null) 'artistId': artistId,
    });
  }

  // ---------------------------------------------------------------------------
  // Scrobbling
  // ---------------------------------------------------------------------------

  /// Registers a play of the given song.
  ///
  /// Set [submission] to `false` to indicate a "now playing" notification
  /// rather than a completed play.
  Future<void> scrobble(String id, {bool? submission}) async {
    await _get('scrobble.view', queryParameters: {
      'id': id,
      if (submission != null) 'submission': submission,
    });
  }

  // ---------------------------------------------------------------------------
  // Similar songs & lyrics
  // ---------------------------------------------------------------------------

  /// Returns songs similar to the given song.
  Future<List<Song>> getSimilarSongs(String id, {int count = 50}) async {
    final data = await _get('getSimilarSongs2.view', queryParameters: {
      'id': id,
      'count': count,
    });
    final songList =
        data['similarSongs2']?['song'] as List<dynamic>?;
    if (songList == null) return [];
    return songList
        .map((s) => Song.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Returns lyrics for the given artist and title, if available.
  ///
  /// Returns `null` if no lyrics are found.
  Future<String?> getLyrics({String? artist, String? title}) async {
    final data = await _get('getLyrics.view', queryParameters: {
      if (artist != null) 'artist': artist,
      if (title != null) 'title': title,
    });
    final lyrics = data['lyrics'] as Map<String, dynamic>?;
    return lyrics?['value'] as String?;
  }
}
