import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';

// -----------------------------------------------------------------------------
// Data providers
// -----------------------------------------------------------------------------

final _recentAlbumsProvider = FutureProvider.autoDispose<List<Album>>((ref) {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) return [];
  return api.getAlbumList(type: 'newest', size: 20);
});

final _frequentAlbumsProvider = FutureProvider.autoDispose<List<Album>>((ref) {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) return [];
  return api.getAlbumList(type: 'frequent', size: 20);
});

final _randomAlbumsProvider = FutureProvider.autoDispose<List<Album>>((ref) {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) return [];
  return api.getAlbumList(type: 'random', size: 20);
});

// -----------------------------------------------------------------------------
// Home screen
// -----------------------------------------------------------------------------

/// The main home screen shown after authentication.
///
/// Displays three horizontally scrolling carousels of albums: recently added,
/// most played, and random picks. Pull to refresh reloads all sections.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _refresh() async {
    ref.invalidate(_recentAlbumsProvider);
    ref.invalidate(_frequentAlbumsProvider);
    ref.invalidate(_randomAlbumsProvider);

    // Wait for all three to complete before the refresh indicator dismisses.
    await Future.wait([
      ref.read(_recentAlbumsProvider.future),
      ref.read(_frequentAlbumsProvider.future),
      ref.read(_randomAlbumsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JUSPlay'),
        actions: [
          Tooltip(
            message: activeServer != null
                ? 'Connected to ${activeServer.name}'
                : 'Not connected',
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                activeServer != null
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                color: activeServer != null
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _AlbumSection(
              title: 'Recently Added',
              provider: _recentAlbumsProvider,
            ),
            _AlbumSection(
              title: 'Most Played',
              provider: _frequentAlbumsProvider,
            ),
            _AlbumSection(
              title: 'Random Albums',
              provider: _randomAlbumsProvider,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Album section (title + horizontal carousel)
// -----------------------------------------------------------------------------

class _AlbumSection extends ConsumerWidget {
  const _AlbumSection({
    required this.title,
    required this.provider,
  });

  final String title;
  final AutoDisposeFutureProvider<List<Album>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAlbums = ref.watch(provider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Carousel content
          SizedBox(
            height: 210,
            child: asyncAlbums.when(
              data: (albums) {
                if (albums.isEmpty) {
                  return Center(
                    child: Text(
                      'No albums found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: albums.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _AlbumCard(album: albums[index]),
                );
              },
              loading: () => _ShimmerCarousel(),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load albums',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Album card
// -----------------------------------------------------------------------------

class _AlbumCard extends ConsumerWidget {
  const _AlbumCard({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = api?.coverArtUrl(album.coverArtId, size: 300) ?? '';

    return GestureDetector(
      onTap: () => context.push('/album/${album.id}'),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover art
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 150,
                height: 150,
                child: coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.album,
                            size: 48,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.album,
                            size: 48,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.album,
                          size: 48,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // Album name
            Text(
              album.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // Artist name
            Text(
              album.artistName ?? 'Unknown Artist',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shimmer loading placeholder
// -----------------------------------------------------------------------------

class _ShimmerCarousel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHigh;
    final highlightColor = colorScheme.surfaceContainerHighest;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
