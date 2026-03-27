class Song {
  final String id;
  final String title;
  final String? album;
  final String? albumId;
  final String? artist;
  final String? artistId;
  final String? coverArtId;
  final int duration;
  final int? bitRate;
  final int? year;
  final String? genre;
  final int? size;
  final String? suffix;
  final String? contentType;
  final String? path;
  final int? discNumber;
  final int? track;
  final DateTime? starred;
  final int playCount;
  final DateTime? created;

  const Song({
    required this.id,
    required this.title,
    this.album,
    this.albumId,
    this.artist,
    this.artistId,
    this.coverArtId,
    this.duration = 0,
    this.bitRate,
    this.year,
    this.genre,
    this.size,
    this.suffix,
    this.contentType,
    this.path,
    this.discNumber,
    this.track,
    this.starred,
    this.playCount = 0,
    this.created,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      album: json['album'] as String?,
      albumId: json['albumId'] as String?,
      artist: json['artist'] as String?,
      artistId: json['artistId'] as String?,
      coverArtId: json['coverArt'] as String?,
      duration: json['duration'] as int? ?? 0,
      bitRate: json['bitRate'] as int?,
      year: json['year'] as int?,
      genre: json['genre'] as String?,
      size: json['size'] as int?,
      suffix: json['suffix'] as String?,
      contentType: json['contentType'] as String?,
      path: json['path'] as String?,
      discNumber: json['discNumber'] as int?,
      track: json['track'] as int?,
      starred: json['starred'] != null
          ? DateTime.parse(json['starred'] as String)
          : null,
      playCount: json['playCount'] as int? ?? 0,
      created: json['created'] != null
          ? DateTime.parse(json['created'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (album != null) 'album': album,
      if (albumId != null) 'albumId': albumId,
      if (artist != null) 'artist': artist,
      if (artistId != null) 'artistId': artistId,
      if (coverArtId != null) 'coverArt': coverArtId,
      'duration': duration,
      if (bitRate != null) 'bitRate': bitRate,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (size != null) 'size': size,
      if (suffix != null) 'suffix': suffix,
      if (contentType != null) 'contentType': contentType,
      if (path != null) 'path': path,
      if (discNumber != null) 'discNumber': discNumber,
      if (track != null) 'track': track,
      if (starred != null) 'starred': starred!.toIso8601String(),
      'playCount': playCount,
      if (created != null) 'created': created!.toIso8601String(),
    };
  }

  /// Returns a human-readable duration string (e.g. "3:45").
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Song copyWith({
    String? id,
    String? title,
    String? album,
    String? albumId,
    String? artist,
    String? artistId,
    String? coverArtId,
    int? duration,
    int? bitRate,
    int? year,
    String? genre,
    int? size,
    String? suffix,
    String? contentType,
    String? path,
    int? discNumber,
    int? track,
    DateTime? starred,
    int? playCount,
    DateTime? created,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      coverArtId: coverArtId ?? this.coverArtId,
      duration: duration ?? this.duration,
      bitRate: bitRate ?? this.bitRate,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      size: size ?? this.size,
      suffix: suffix ?? this.suffix,
      contentType: contentType ?? this.contentType,
      path: path ?? this.path,
      discNumber: discNumber ?? this.discNumber,
      track: track ?? this.track,
      starred: starred ?? this.starred,
      playCount: playCount ?? this.playCount,
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Song(id: $id, title: $title, artist: $artist)';
}
