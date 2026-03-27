import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/providers/providers.dart';
import '../../../core/models/models.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _artistsProvider = FutureProvider<List<Artist>>((ref) async {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) return [];
  return api.getArtists();
});

final _albumsProvider = FutureProvider<List<Album>>((ref) async {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) return [];
  // Load all albums alphabetically; fetch in batches to get a complete list.
  final albums = <Album>[];
  const batchSize = 500;
  int offset = 0;
  while (true) {
    final batch = await api.getAlbumList(
      type: 'alphabeticalByName',
      size: batchSize,
      offset: offset,
    );
    albums.addAll(batch);
    if (batch.length < batchSize) break;
    offset += batchSize;
  }
  return albums;
});

final _genresProvider = FutureProvider<List<Genre>>((ref) async {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) return [];
  final genres = await api.getGenres();
  genres.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return genres;
});

// ---------------------------------------------------------------------------
// Library screen
// ---------------------------------------------------------------------------

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['Artists', 'Albums', 'Genres'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: const Text('Library'),
              floating: true,
              snap: true,
              forceElevated: innerBoxIsScrolled,
              bottom: TabBar(
                controller: _tabController,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
                indicatorColor: colorScheme.primary,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.label,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [
            _ArtistsTab(),
            _AlbumsTab(),
            _GenresTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Artists tab
// ---------------------------------------------------------------------------

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(_artistsProvider);

    return artistsAsync.when(
      loading: () => const _ArtistListShimmer(),
      error: (error, stack) => _ErrorView(
        message: 'Failed to load artists',
        onRetry: () => ref.invalidate(_artistsProvider),
      ),
      data: (artists) {
        if (artists.isEmpty) {
          return const _EmptyView(message: 'No artists found');
        }
        return _ArtistListWithIndex(artists: artists);
      },
    );
  }
}

class _ArtistListWithIndex extends ConsumerStatefulWidget {
  const _ArtistListWithIndex({required this.artists});

  final List<Artist> artists;

  @override
  ConsumerState<_ArtistListWithIndex> createState() =>
      _ArtistListWithIndexState();
}

class _ArtistListWithIndexState extends ConsumerState<_ArtistListWithIndex> {
  final ScrollController _scrollController = ScrollController();

  /// Map from letter -> first index in the sorted list.
  late final Map<String, int> _letterIndex;
  late final List<String> _letters;

  @override
  void initState() {
    super.initState();
    _buildIndex();
  }

  void _buildIndex() {
    _letterIndex = {};
    for (var i = 0; i < widget.artists.length; i++) {
      final letter = _firstLetter(widget.artists[i].name);
      _letterIndex.putIfAbsent(letter, () => i);
    }
    _letters = _letterIndex.keys.toList()..sort();
  }

  String _firstLetter(String name) {
    if (name.isEmpty) return '#';
    final ch = name[0].toUpperCase();
    if (RegExp(r'[A-Z]').hasMatch(ch)) return ch;
    return '#';
  }

  void _scrollToLetter(String letter) {
    final index = _letterIndex[letter];
    if (index == null) return;
    // Estimate item height at ~64 logical pixels (ListTile default).
    final offset = index * 64.0;
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final api = ref.watch(subsonicApiProvider);

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(right: 28),
          itemCount: widget.artists.length,
          itemBuilder: (context, index) {
            final artist = widget.artists[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.surfaceContainerHigh,
                backgroundImage: artist.coverArtId != null && api != null
                    ? CachedNetworkImageProvider(
                        api.coverArtUrl(artist.coverArtId, size: 100),
                      )
                    : null,
                child: artist.coverArtId == null
                    ? Icon(Icons.person, color: colorScheme.onSurfaceVariant)
                    : null,
              ),
              title: Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${artist.albumCount} ${artist.albumCount == 1 ? 'album' : 'albums'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () => context.push('/artist/${artist.id}'),
            );
          },
        ),

        // A-Z sidebar index
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _letters.map((letter) {
                  return GestureDetector(
                    onTap: () => _scrollToLetter(letter),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 1,
                        horizontal: 6,
                      ),
                      child: Text(
                        letter,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Albums tab
// ---------------------------------------------------------------------------

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(_albumsProvider);

    return albumsAsync.when(
      loading: () => const _AlbumGridShimmer(),
      error: (error, stack) => _ErrorView(
        message: 'Failed to load albums',
        onRetry: () => ref.invalidate(_albumsProvider),
      ),
      data: (albums) {
        if (albums.isEmpty) {
          return const _EmptyView(message: 'No albums found');
        }
        return _AlbumGrid(albums: albums);
      },
    );
  }
}

class _AlbumGrid extends ConsumerWidget {
  const _AlbumGrid({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsonicApiProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
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
                          imageUrl:
                              api.coverArtUrl(album.coverArtId, size: 300),
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
              if (album.artistName != null)
                Text(
                  album.artistName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Genres tab
// ---------------------------------------------------------------------------

class _GenresTab extends ConsumerWidget {
  const _GenresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(_genresProvider);

    return genresAsync.when(
      loading: () => const _GenreListShimmer(),
      error: (error, stack) => _ErrorView(
        message: 'Failed to load genres',
        onRetry: () => ref.invalidate(_genresProvider),
      ),
      data: (genres) {
        if (genres.isEmpty) {
          return const _EmptyView(message: 'No genres found');
        }
        return _GenreList(genres: genres);
      },
    );
  }
}

class _GenreList extends StatelessWidget {
  const _GenreList({required this.genres});

  final List<Genre> genres;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: genres.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final genre = genres[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.music_note,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            genre.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${genre.albumCount} ${genre.albumCount == 1 ? 'album' : 'albums'}'
            ' \u00B7 '
            '${genre.songCount} ${genre.songCount == 1 ? 'song' : 'songs'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer placeholders
// ---------------------------------------------------------------------------

class _ArtistListShimmer extends StatelessWidget {
  const _ArtistListShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHigh,
      highlightColor: colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        itemCount: 15,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(),
            title: Container(
              height: 14,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            subtitle: Container(
              height: 10,
              width: 60,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlbumGridShimmer extends StatelessWidget {
  const _AlbumGridShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHigh,
      highlightColor: colorScheme.surfaceContainerHighest,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Column(
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
                width: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GenreListShimmer extends StatelessWidget {
  const _GenreListShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHigh,
      highlightColor: colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(),
            title: Container(
              height: 14,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            subtitle: Container(
              height: 10,
              width: 140,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared utility widgets
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
