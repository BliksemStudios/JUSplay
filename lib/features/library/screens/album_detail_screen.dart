import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/api/api.dart';
import '../../../core/audio/audio.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/models.dart';
import '../../player/widgets/mini_player.dart';

// ---------------------------------------------------------------------------
// Data class holding album info + its songs
// ---------------------------------------------------------------------------

class _AlbumDetail {
  final Album album;
  final List<Song> songs;

  const _AlbumDetail({required this.album, required this.songs});
}

// ---------------------------------------------------------------------------
// Provider – fetches getAlbum and extracts the nested song list
// ---------------------------------------------------------------------------

final _albumDetailProvider =
    FutureProvider.family<_AlbumDetail, String>((ref, albumId) async {
  final server = ref.watch(activeServerProvider);
  if (server == null) {
    throw Exception('No server configured');
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: '${server.url}/rest/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  final params = {
    ...server.authParams(),
    'id': albumId,
  };

  final response = await dio.get<Map<String, dynamic>>(
    'getAlbum.view',
    queryParameters: params,
  );

  final subsonicResponse =
      response.data!['subsonic-response'] as Map<String, dynamic>;
  if (subsonicResponse['status'] != 'ok') {
    final error = subsonicResponse['error'] as Map<String, dynamic>;
    throw Exception(error['message'] ?? 'Unknown error');
  }

  final albumJson = subsonicResponse['album'] as Map<String, dynamic>;
  final album = Album.fromJson(albumJson);

  final songJsonList = albumJson['song'] as List<dynamic>? ?? [];
  final songs = songJsonList
      .map((s) => Song.fromJson(s as Map<String, dynamic>))
      .toList();

  // Sort by disc number then track number
  songs.sort((a, b) {
    final discCmp = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
    if (discCmp != 0) return discCmp;
    return (a.track ?? 0).compareTo(b.track ?? 0);
  });

  return _AlbumDetail(album: album, songs: songs);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_albumDetailProvider(albumId));
    final api = ref.watch(subsonicApiProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      body: detailAsync.when(
        loading: () => _buildLoadingState(context),
        error: (error, stack) => CustomScrollView(
          slivers: [
            const SliverAppBar(title: Text('Album')),
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load album',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(_albumDetailProvider(albumId)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        data: (detail) =>
            _AlbumContent(detail: detail, api: api),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('Loading...')),
        SliverToBoxAdapter(
          child: Shimmer.fromColors(
            baseColor: colorScheme.surfaceContainerHigh,
            highlightColor: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Album art placeholder
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 20,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Track list placeholders
                  ...List.generate(
                    8,
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 14,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 10,
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Album content (header + track list)
// ---------------------------------------------------------------------------

class _AlbumContent extends ConsumerWidget {
  const _AlbumContent({required this.detail, required this.api});

  final _AlbumDetail detail;
  final SubsonicApi? api;

  String _formatTotalDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  void _playAll(WidgetRef ref, List<Song> songs) {
    if (songs.isEmpty || api == null) return;
    final handler = ref.read(audioHandlerProvider);
    handler.playQueue(
      songs,
      startIndex: 0,
      getStreamUrl: (id) => api!.streamUrl(id),
      getCoverArtUrl: (id) => api!.coverArtUrl(id),
    );
  }

  void _shuffleAll(WidgetRef ref, List<Song> songs) {
    if (songs.isEmpty || api == null) return;
    final shuffled = List<Song>.from(songs)..shuffle();
    final handler = ref.read(audioHandlerProvider);
    handler.playQueue(
      shuffled,
      startIndex: 0,
      getStreamUrl: (id) => api!.streamUrl(id),
      getCoverArtUrl: (id) => api!.coverArtUrl(id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final album = detail.album;
    final songs = detail.songs;

    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          pinned: true,
          expandedHeight: 0,
          title: Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Header: album art + info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Large album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: album.coverArtId != null && api != null
                        ? CachedNetworkImage(
                            imageUrl:
                                api!.coverArtUrl(album.coverArtId, size: 600),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: colorScheme.surfaceContainerHigh,
                              child: const Center(
                                child: Icon(Icons.album, size: 64),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: colorScheme.surfaceContainerHigh,
                              child: const Center(
                                child: Icon(Icons.album, size: 64),
                              ),
                            ),
                          )
                        : Container(
                            color: colorScheme.surfaceContainerHigh,
                            child: Center(
                              child: Icon(
                                Icons.album,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Album name
                Text(
                  album.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Artist name (tappable)
                if (album.artistName != null)
                  GestureDetector(
                    onTap: () {
                      if (album.artistId != null) {
                        context.push('/artist/${album.artistId}');
                      }
                    },
                    child: Text(
                      album.artistName!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),

                // Year, duration, song count
                Text(
                  [
                    if (album.year != null) '${album.year}',
                    _formatTotalDuration(album.duration),
                    '${album.songCount} ${album.songCount == 1 ? 'song' : 'songs'}',
                  ].join(' \u00B7 '),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: songs.isNotEmpty
                          ? () => _playAll(ref, songs)
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play All'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: songs.isNotEmpty
                          ? () => _shuffleAll(ref, songs)
                          : null,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Divider
        const SliverToBoxAdapter(
          child: Divider(height: 1, indent: 16, endIndent: 16),
        ),

        // Track list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final song = songs[index];
              return _TrackTile(
                song: song,
                index: index,
                songs: songs,
              );
            },
            childCount: songs.length,
          ),
        ),

        // Bottom padding
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Track tile
// ---------------------------------------------------------------------------

class _TrackTile extends ConsumerWidget {
  const _TrackTile({
    required this.song,
    required this.index,
    required this.songs,
  });

  final Song song;
  final int index;
  final List<Song> songs;

  void _playFromIndex(WidgetRef ref) {
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    final handler = ref.read(audioHandlerProvider);
    handler.playQueue(
      songs,
      startIndex: index,
      getStreamUrl: (id) => api.streamUrl(id),
      getCoverArtUrl: (id) => api.coverArtUrl(id),
    );
  }

  void _addToQueue(WidgetRef ref) {
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    final handler = ref.read(audioHandlerProvider);
    handler.addToQueue(
      song,
      streamUrl: api.streamUrl(song.id),
      coverArtUrl: api.coverArtUrl(song.coverArtId),
    );
  }

  Future<void> _toggleStar(WidgetRef ref) async {
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    try {
      if (song.starred != null) {
        await api.unstar(id: song.id);
      } else {
        await api.star(id: song.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: SizedBox(
        width: 32,
        child: Center(
          child: Text(
            '${song.track ?? (index + 1)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: song.artist != null
          ? Text(
              song.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            song.formattedDuration,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: () => _showTrackMenu(context, ref),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      onTap: () => _playFromIndex(ref),
    );
  }

  void _showAddToPlaylistSheet(
      BuildContext context, WidgetRef ref, Song targetSong) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final api = ref.watch(subsonicApiProvider);
            if (api == null) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Not connected')),
              );
            }

            return FutureBuilder(
              future: api.getPlaylists(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final playlists = snapshot.data ?? [];
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Add to playlist',
                          style:
                              Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      const Divider(height: 1),
                      if (playlists.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No playlists found'),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: playlists.length,
                            itemBuilder: (ctx, i) {
                              final pl = playlists[i];
                              return ListTile(
                                leading: const Icon(Icons.queue_music),
                                title: Text(pl.name),
                                subtitle: Text(
                                    '${pl.songCount} song${pl.songCount == 1 ? '' : 's'}'),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  try {
                                    await api.updatePlaylist(
                                      id: pl.id,
                                      songIdsToAdd: [targetSong.id],
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Added to ${pl.name}'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Failed to add: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTrackMenu(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  song.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.queue_music,
                    color: colorScheme.onSurfaceVariant),
                title: const Text('Add to queue'),
                onTap: () {
                  Navigator.pop(context);
                  _addToQueue(ref);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to queue')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.playlist_add,
                    color: colorScheme.onSurfaceVariant),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistSheet(context, ref, song);
                },
              ),
              ListTile(
                leading: Icon(
                  song.starred != null ? Icons.star : Icons.star_border,
                  color: song.starred != null
                      ? Colors.amber
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(
                    song.starred != null ? 'Remove from favorites' : 'Star'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleStar(ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
