import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final String? comment;
  final String? owner;
  final bool public;
  final int songCount;
  final int duration;
  final String? coverArtId;
  final DateTime? created;
  final DateTime? changed;
  final List<Song> songs;

  const Playlist({
    required this.id,
    required this.name,
    this.comment,
    this.owner,
    this.public = false,
    this.songCount = 0,
    this.duration = 0,
    this.coverArtId,
    this.created,
    this.changed,
    this.songs = const [],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final entryList = json['entry'] as List<dynamic>?;
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      comment: json['comment'] as String?,
      owner: json['owner'] as String?,
      public: json['public'] as bool? ?? false,
      songCount: json['songCount'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      coverArtId: json['coverArt'] as String?,
      created: json['created'] != null
          ? DateTime.parse(json['created'] as String)
          : null,
      changed: json['changed'] != null
          ? DateTime.parse(json['changed'] as String)
          : null,
      songs: entryList
              ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (comment != null) 'comment': comment,
      if (owner != null) 'owner': owner,
      'public': public,
      'songCount': songCount,
      'duration': duration,
      if (coverArtId != null) 'coverArt': coverArtId,
      if (created != null) 'created': created!.toIso8601String(),
      if (changed != null) 'changed': changed!.toIso8601String(),
      if (songs.isNotEmpty) 'entry': songs.map((s) => s.toJson()).toList(),
    };
  }

  /// Returns a human-readable duration string (e.g. "1:02:30").
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? comment,
    String? owner,
    bool? public,
    int? songCount,
    int? duration,
    String? coverArtId,
    DateTime? created,
    DateTime? changed,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      comment: comment ?? this.comment,
      owner: owner ?? this.owner,
      public: public ?? this.public,
      songCount: songCount ?? this.songCount,
      duration: duration ?? this.duration,
      coverArtId: coverArtId ?? this.coverArtId,
      created: created ?? this.created,
      changed: changed ?? this.changed,
      songs: songs ?? this.songs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Playlist(id: $id, name: $name, songCount: $songCount)';
}
