import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/api/api.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/models.dart';
import '../../player/widgets/mini_player.dart';

// ---------------------------------------------------------------------------
// Data class holding artist info + its albums
// ---------------------------------------------------------------------------

class _ArtistDetail {
  final Artist artist;
  final List<Album> albums;

  const _ArtistDetail({required this.artist, required this.albums});
}

// ---------------------------------------------------------------------------
// Provider – fetches getArtist and extracts the nested album list
// ---------------------------------------------------------------------------

final _artistDetailProvider =
    FutureProvider.family<_ArtistDetail, String>((ref, artistId) async {
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
    'id': artistId,
  };

  final response = await dio.get<Map<String, dynamic>>(
    'getArtist.view',
    queryParameters: params,
  );

  final subsonicResponse =
      response.data!['subsonic-response'] as Map<String, dynamic>;
  if (subsonicResponse['status'] != 'ok') {
    final error = subsonicResponse['error'] as Map<String, dynamic>;
    throw Exception(error['message'] ?? 'Unknown error');
  }

  final artistJson = subsonicResponse['artist'] as Map<String, dynamic>;
  final artist = Artist.fromJson(artistJson);

  final albumJsonList = artistJson['album'] as List<dynamic>? ?? [];
  final albums = albumJsonList
      .map((a) => Album.fromJson(a as Map<String, dynamic>))
      .toList();

  return _ArtistDetail(artist: artist, albums: albums);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_artistDetailProvider(artistId));
    final api = ref.watch(subsonicApiProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      bottomNavigationBar: const MiniPlayer(standalone: true),
      body: detailAsync.when(
        loading: () => _buildLoadingState(context),
        error: (error, stack) => CustomScrollView(
          slivers: [
            const SliverAppBar(title: Text('Artist')),
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
                        'Failed to load artist',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(_artistDetailProvider(artistId)),
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
        data: (detail) {
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(detail.artist.name),
                expandedHeight: 200,
                flexibleSpace: FlexibleSpaceBar(
                  background: detail.artist.coverArtId != null && api != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: api.coverArtUrl(
                                  detail.artist.coverArtId,
                                  size: 600),
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const SizedBox(),
                            ),
                            // Gradient overlay for readability
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    colorScheme.surface,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),

              // Album count summary
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${detail.albums.length} ${detail.albums.length == 1 ? 'album' : 'albums'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              // Albums grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = detail.albums[index];
                      return _AlbumCard(album: album, api: api);
                    },
                    childCount: detail.albums.length,
                  ),
                ),
              ),

              // Bottom padding so content isn't clipped
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('Loading...')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Shimmer.fromColors(
                  baseColor: colorScheme.surfaceContainerHigh,
                  highlightColor: colorScheme.surfaceContainerHighest,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 10,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Album card widget
// ---------------------------------------------------------------------------

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.api});

  final Album album;
  final SubsonicApi? api;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => context.push('/album/${album.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: album.coverArtId != null && api != null
                  ? CachedNetworkImage(
                      imageUrl: api!.coverArtUrl(album.coverArtId, size: 300),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: const Center(
                          child: Icon(Icons.album, size: 48),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: const Center(
                          child: Icon(Icons.album, size: 48),
                        ),
                      ),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHigh,
                      child: Center(
                        child: Icon(
                          Icons.album,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            [
              if (album.year != null) '${album.year}',
              '${album.songCount} ${album.songCount == 1 ? 'song' : 'songs'}',
            ].join(' \u00B7 '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
