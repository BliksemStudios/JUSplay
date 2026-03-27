class Genre {
  final String name;
  final int songCount;
  final int albumCount;

  const Genre({
    required this.name,
    this.songCount = 0,
    this.albumCount = 0,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      name: json['value'] as String? ?? '',
      songCount: json['songCount'] as int? ?? 0,
      albumCount: json['albumCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': name,
      'songCount': songCount,
      'albumCount': albumCount,
    };
  }

  Genre copyWith({
    String? name,
    int? songCount,
    int? albumCount,
  }) {
    return Genre(
      name: name ?? this.name,
      songCount: songCount ?? this.songCount,
      albumCount: albumCount ?? this.albumCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Genre &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() =>
      'Genre(name: $name, songs: $songCount, albums: $albumCount)';
}
