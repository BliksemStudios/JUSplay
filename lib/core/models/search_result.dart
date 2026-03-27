import 'artist.dart';
import 'album.dart';
import 'song.dart';

class SearchResult {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;

  const SearchResult({
    this.artists = const [],
    this.albums = const [],
    this.songs = const [],
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final artistList = json['artist'] as List<dynamic>?;
    final albumList = json['album'] as List<dynamic>?;
    final songList = json['song'] as List<dynamic>?;
    return SearchResult(
      artists: artistList
              ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      albums: albumList
              ?.map((e) => Album.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      songs: songList
              ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isEmpty => artists.isEmpty && albums.isEmpty && songs.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get totalCount => artists.length + albums.length + songs.length;

  @override
  String toString() =>
      'SearchResult(artists: ${artists.length}, albums: ${albums.length}, songs: ${songs.length})';
}
