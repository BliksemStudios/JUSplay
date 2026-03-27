import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/audio/audio.dart';
import '../../player/widgets/mini_player.dart';

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  List<Song>? _songs;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final songs = await api.getStarred();
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _playAll() {
    final songs = _songs;
    if (songs == null || songs.isEmpty) return;
    final handler = ref.read(audioHandlerProvider);
    final api = ref.read(subsonicApiProvider)!;
    handler.playQueue(
      songs,
      startIndex: 0,
      getStreamUrl: (id) => api.streamUrl(id),
      getCoverArtUrl: (id) => api.coverArtUrl(id),
    );
  }

  void _shuffleAll() {
    final songs = _songs;
    if (songs == null || songs.isEmpty) return;
    final shuffled = List<Song>.from(songs)..shuffle();
    final handler = ref.read(audioHandlerProvider);
    final api = ref.read(subsonicApiProvider)!;
    handler.playQueue(
      shuffled,
      startIndex: 0,
      getStreamUrl: (id) => api.streamUrl(id),
      getCoverArtUrl: (id) => api.coverArtUrl(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      bottomNavigationBar: const MiniPlayer(standalone: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: colorScheme.error),
                      const SizedBox(height: 12),
                      Text('Failed to load favourites',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadFavourites,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(theme, colorScheme),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    final songs = _songs ?? [];

    return RefreshIndicator(
      onRefresh: _loadFavourites,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Favourites'),
            floating: true,
          ),
          if (songs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${songs.length} song${songs.length == 1 ? '' : 's'}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: _shuffleAll,
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text('Shuffle'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _playAll,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Play'),
                    ),
                  ],
                ),
              ),
            ),
          if (songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border,
                        size: 64,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('No favourites yet',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Star songs to add them here',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = songs[index];
                  final api = ref.read(subsonicApiProvider);
                  final artUrl = api?.coverArtUrl(song.coverArtId, size: 80);

                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: artUrl != null
                            ? CachedNetworkImage(
                                imageUrl: artUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    _placeholder(colorScheme),
                                errorWidget: (_, _, _) =>
                                    _placeholder(colorScheme),
                              )
                            : _placeholder(colorScheme),
                      ),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.favorite,
                          color: colorScheme.primary, size: 20),
                      onPressed: () async {
                        try {
                          await api?.unstar(id: song.id);
                          await _loadFavourites();
                        } catch (_) {}
                      },
                    ),
                    onTap: () {
                      final handler = ref.read(audioHandlerProvider);
                      handler.playQueue(
                        songs,
                        startIndex: index,
                        getStreamUrl: (id) => api!.streamUrl(id),
                        getCoverArtUrl: (id) => api!.coverArtUrl(id),
                      );
                    },
                  );
                },
                childCount: songs.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.surfaceContainerHigh,
        child: Icon(Icons.music_note, size: 20, color: cs.onSurfaceVariant),
      );
}
