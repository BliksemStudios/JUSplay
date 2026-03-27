class Album {
  final String id;
  final String name;
  final String? artistId;
  final String? artistName;
  final String? coverArtId;
  final int songCount;
  final int duration;
  final int? year;
  final String? genre;
  final DateTime? starred;
  final int playCount;
  final DateTime? created;

  const Album({
    required this.id,
    required this.name,
    this.artistId,
    this.artistName,
    this.coverArtId,
    this.songCount = 0,
    this.duration = 0,
    this.year,
    this.genre,
    this.starred,
    this.playCount = 0,
    this.created,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['title'] as String? ?? '',
      artistId: json['artistId'] as String?,
      artistName: json['artist'] as String?,
      coverArtId: json['coverArt'] as String?,
      songCount: json['songCount'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      year: json['year'] as int?,
      genre: json['genre'] as String?,
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
      'name': name,
      if (artistId != null) 'artistId': artistId,
      if (artistName != null) 'artist': artistName,
      if (coverArtId != null) 'coverArt': coverArtId,
      'songCount': songCount,
      'duration': duration,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (starred != null) 'starred': starred!.toIso8601String(),
      'playCount': playCount,
      if (created != null) 'created': created!.toIso8601String(),
    };
  }

  /// Returns a human-readable duration string (e.g. "42:15" or "1:02:30").
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Album copyWith({
    String? id,
    String? name,
    String? artistId,
    String? artistName,
    String? coverArtId,
    int? songCount,
    int? duration,
    int? year,
    String? genre,
    DateTime? starred,
    int? playCount,
    DateTime? created,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      coverArtId: coverArtId ?? this.coverArtId,
      songCount: songCount ?? this.songCount,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      starred: starred ?? this.starred,
      playCount: playCount ?? this.playCount,
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Album && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Album(id: $id, name: $name, artist: $artistName)';
}
