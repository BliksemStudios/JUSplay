class Artist {
  final String id;
  final String name;
  final String? coverArtId;
  final int albumCount;
  final DateTime? starred;

  const Artist({
    required this.id,
    required this.name,
    this.coverArtId,
    this.albumCount = 0,
    this.starred,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String,
      name: json['name'] as String,
      coverArtId: json['coverArt'] as String?,
      albumCount: json['albumCount'] as int? ?? 0,
      starred: json['starred'] != null
          ? DateTime.parse(json['starred'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coverArt': coverArtId,
      'albumCount': albumCount,
      if (starred != null) 'starred': starred!.toIso8601String(),
    };
  }

  Artist copyWith({
    String? id,
    String? name,
    String? coverArtId,
    int? albumCount,
    DateTime? starred,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      coverArtId: coverArtId ?? this.coverArtId,
      albumCount: albumCount ?? this.albumCount,
      starred: starred ?? this.starred,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Artist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Artist(id: $id, name: $name)';
}
