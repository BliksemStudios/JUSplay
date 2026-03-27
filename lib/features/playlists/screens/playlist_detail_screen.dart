import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/audio/audio.dart';
import '../../player/widgets/mini_player.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  Playlist? _playlist;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    final api = ref.read(subsonicApiProvider);
    if (api == null) {
      setState(() {
        _isLoading = false;
        _error = 'Not connected to a server';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final playlist = await api.getPlaylist(widget.playlistId);
      if (mounted) {
        setState(() {
          _playlist = playlist;
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

  void _playSong(List<Song> songs, int index) {
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

  void _playAll() {
    final songs = _playlist?.songs ?? [];
    if (songs.isEmpty) return;
    _playSong(songs, 0);
  }

  void _shuffleAll() {
    final songs = List<Song>.from(_playlist?.songs ?? []);
    if (songs.isEmpty) return;
    songs.shuffle();
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    final handler = ref.read(audioHandlerProvider);
    handler.player.setShuffleModeEnabled(true);
    handler.playQueue(
      songs,
      startIndex: 0,
      getStreamUrl: (id) => api.streamUrl(id),
      getCoverArtUrl: (id) => api.coverArtUrl(id),
    );
  }

  void _showSongMenu(BuildContext context, Song song) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final api = ref.read(subsonicApiProvider);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(song.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.queue_music,
                    color: colorScheme.onSurfaceVariant),
                title: const Text('Add to queue'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (api != null) {
                    ref.read(audioHandlerProvider).addToQueue(
                          song,
                          streamUrl: api.streamUrl(song.id),
                          coverArtUrl: api.coverArtUrl(song.coverArtId),
                        );
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Added to queue')));
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_awesome,
                    color: colorScheme.onSurfaceVariant),
                title: const Text('Create smart playlist'),
                onTap: () {
                  Navigator.pop(ctx);
                  final parts = <String>[
                    'Songs similar to "${song.title}"',
                    if (song.artist != null) 'by ${song.artist}',
                    if (song.genre != null) '— ${song.genre} vibes',
                  ];
                  context.push(Uri(
                    path: '/smart-playlist',
                    queryParameters: {'prompt': parts.join(' ')},
                  ).toString());
                },
              ),
              ListTile(
                leading: Icon(
                  song.starred != null ? Icons.favorite : Icons.favorite_border,
                  color: song.starred != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(song.starred != null ? 'Remove from favourites' : 'Love'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    if (song.starred != null) {
                      await api?.unstar(id: song.id);
                    } else {
                      await api?.star(id: song.id);
                    }
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeFromPlaylist(int songIndex) async {
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;

    try {
      await api.updatePlaylist(
        id: widget.playlistId,
        songIndexesToRemove: [songIndex],
      );
      _loadPlaylist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Song removed from playlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove song: $e')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final api = ref.watch(subsonicApiProvider);

    return Scaffold(
      bottomNavigationBar: const MiniPlayer(standalone: true),
      body: api == null
          ? _buildNotConnected(colorScheme)
          : _isLoading && _playlist == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _playlist == null
                  ? _buildError(theme, colorScheme)
                  : _buildBody(context, theme, colorScheme),
    );
  }

  Widget _buildNotConnected(ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('Playlist'),
          leading: const BackButton(),
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off,
                    size: 64, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('Not connected to a server',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(ThemeData theme, ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('Playlist'),
          leading: const BackButton(),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: colorScheme.error),
                  const SizedBox(height: 12),
                  Text('Failed to load playlist',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadPlaylist,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final playlist = _playlist!;
    final api = ref.read(subsonicApiProvider);
    final coverUrl = api?.coverArtUrl(playlist.coverArtId, size: 300) ?? '';

    return CustomScrollView(
      slivers: [
        // Header
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          leading: const BackButton(),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: colorScheme.surfaceContainerHigh,
                    ),
                  )
                else
                  Container(
                    color: colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.queue_music,
                        size: 80, color: colorScheme.onSurfaceVariant),
                  ),
                // Gradient overlay for readability
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Info + buttons
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${playlist.songCount} song${playlist.songCount == 1 ? '' : 's'} \u2022 ${_formatTotalDuration(playlist.duration)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: playlist.songs.isNotEmpty ? _playAll : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            playlist.songs.isNotEmpty ? _shuffleAll : null,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Song list
        if (playlist.songs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'This playlist is empty',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = playlist.songs[index];
                final artUrl =
                    api?.coverArtUrl(song.coverArtId, size: 80) ?? '';
                return Slidable(
                  endActionPane: ActionPane(
                    motion: const BehindMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) => _removeFromPlaylist(index),
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        icon: Icons.delete,
                        label: 'Remove',
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: artUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: artUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  color: colorScheme.surfaceContainerHigh,
                                  child: Icon(Icons.music_note,
                                      color: colorScheme.onSurfaceVariant,
                                      size: 20),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color: colorScheme.surfaceContainerHigh,
                                  child: Icon(Icons.music_note,
                                      color: colorScheme.onSurfaceVariant,
                                      size: 20),
                                ),
                              )
                            : Container(
                                color: colorScheme.surfaceContainerHigh,
                                child: Icon(Icons.music_note,
                                    color: colorScheme.onSurfaceVariant,
                                    size: 20),
                              ),
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
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(song.duration),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.more_vert,
                              color: colorScheme.onSurfaceVariant, size: 20),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showSongMenu(context, song),
                        ),
                      ],
                    ),
                    onTap: () =>
                        _playSong(playlist.songs, index),
                  ),
                );
              },
              childCount: playlist.songs.length,
            ),
          ),
      ],
    );
  }
}
