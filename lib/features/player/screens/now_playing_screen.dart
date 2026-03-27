import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/providers/providers.dart';
import '../../../core/audio/audio.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentSongProvider);
    final playbackAsync = ref.watch(playbackStateProvider);
    final positionAsync = ref.watch(positionProvider);
    final durationAsync = ref.watch(durationProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final mediaItem = mediaItemAsync.valueOrNull;
    final playbackState = playbackAsync.valueOrNull;
    final position = positionAsync.valueOrNull ?? Duration.zero;
    final duration = durationAsync.valueOrNull ?? Duration.zero;

    if (mediaItem == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_off,
                  size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Nothing playing',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    final isPlaying = playbackState?.playing ?? false;
    final shuffleEnabled =
        playbackState?.shuffleMode == AudioServiceShuffleMode.all;
    final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
    final artUri = mediaItem.artUri;
    final totalSeconds = duration.inSeconds;
    final currentSeconds =
        position.inSeconds.clamp(0, totalSeconds > 0 ? totalSeconds : 1);

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              context.pop();
            }
          },
          child: Column(
            children: [
              // Drag handle + close
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                    ),
                    Text(
                      'Now Playing',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _showQueueSheet(context, ref, colorScheme),
                      icon: const Icon(Icons.queue_music),
                    ),
                  ],
                ),
              ),

              // Album art
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: artUri != null
                            ? CachedNetworkImage(
                                imageUrl: artUri.toString(),
                                fit: BoxFit.cover,
                                placeholder: (_, _) => _artPlaceholder(
                                    colorScheme),
                                errorWidget: (_, _, _) =>
                                    _artPlaceholder(colorScheme),
                              )
                            : _artPlaceholder(colorScheme),
                      ),
                    ),
                  ),
                ),
              ),

              // Song info
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Column(
                  children: [
                    // Title + star button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mediaItem.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mediaItem.artist ?? 'Unknown Artist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              if (mediaItem.album != null)
                                Text(
                                  mediaItem.album!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _toggleStar(ref, mediaItem),
                          icon: Icon(
                            Icons.favorite_border,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showSongMenu(context, ref, mediaItem),
                          icon: Icon(
                            Icons.more_vert,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Progress bar
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: currentSeconds.toDouble(),
                        max: totalSeconds > 0 ? totalSeconds.toDouble() : 1.0,
                        onChanged: (value) {
                          final handler = ref.read(audioHandlerProvider);
                          handler.seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),

                    // Time labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            final handler = ref.read(audioHandlerProvider);
                            handler.player.setShuffleModeEnabled(!shuffleEnabled);
                          },
                          icon: Icon(
                            Icons.shuffle,
                            color: shuffleEnabled
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final handler = ref.read(audioHandlerProvider);
                            handler.skipToPrevious();
                          },
                          iconSize: 36,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        // Play / Pause (large)
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: FilledButton(
                            onPressed: () {
                              final handler = ref.read(audioHandlerProvider);
                              if (isPlaying) {
                                handler.pause();
                              } else {
                                handler.play();
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 36,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final handler = ref.read(audioHandlerProvider);
                            handler.skipToNext();
                          },
                          iconSize: 36,
                          icon: const Icon(Icons.skip_next),
                        ),
                        IconButton(
                          onPressed: () {
                            final handler = ref.read(audioHandlerProvider);
                            // Cycle: off -> all -> one -> off
                            switch (repeatMode) {
                              case AudioServiceRepeatMode.none:
                                handler.player.setLoopMode(ja.LoopMode.all);
                              case AudioServiceRepeatMode.all:
                              case AudioServiceRepeatMode.group:
                                handler.player.setLoopMode(ja.LoopMode.one);
                              case AudioServiceRepeatMode.one:
                                handler.player.setLoopMode(ja.LoopMode.off);
                            }
                          },
                          icon: Icon(
                            repeatMode == AudioServiceRepeatMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: repeatMode != AudioServiceRepeatMode.none
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _artPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHigh,
      child:
          Icon(Icons.album, size: 80, color: colorScheme.onSurfaceVariant),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSongMenu(BuildContext context, WidgetRef ref, MediaItem mediaItem) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final songId = mediaItem.extras?['songId'] as String?;

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
                  mediaItem.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.playlist_add,
                    color: colorScheme.onSurfaceVariant),
                title: const Text('Add to playlist'),
                onTap: () {
                  Navigator.pop(context);
                  if (songId != null) {
                    _showAddToPlaylistSheet(context, ref, songId);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_awesome,
                    color: colorScheme.onSurfaceVariant),
                title: const Text('Create smart playlist'),
                subtitle: Text(
                  'Find similar songs using AI',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final parts = <String>[
                    'Songs similar to "${mediaItem.title}"',
                    if (mediaItem.artist != null) 'by ${mediaItem.artist}',
                    if (mediaItem.genre != null) '— ${mediaItem.genre} vibes',
                  ];
                  context.push(
                    Uri(
                      path: '/smart-playlist',
                      queryParameters: {'prompt': parts.join(' ')},
                    ).toString(),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.favorite_border,
                    color: colorScheme.onSurfaceVariant),
                title: const Text('Love'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleStar(ref, mediaItem);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, WidgetRef ref, String songId) async {
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    try {
      final playlists = await api.getPlaylists();
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Add to playlist',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const Divider(height: 1),
                if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No playlists yet'),
                  )
                else
                  ...playlists.map((p) => ListTile(
                        leading: const Icon(Icons.queue_music),
                        title: Text(p.name),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await api.updatePlaylist(
                                id: p.id, songIdsToAdd: [songId]);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Added to "${p.name}"')),
                              );
                            }
                          } catch (_) {}
                        },
                      )),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    } catch (_) {}
  }

  Future<void> _toggleStar(WidgetRef ref, MediaItem mediaItem) async {
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    final songId = mediaItem.extras?['songId'] as String?;
    if (songId == null) return;
    try {
      await api.star(id: songId);
    } catch (_) {
      // Best-effort star toggle
    }
  }

  void _showQueueSheet(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    final handler = ref.read(audioHandlerProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        // Read queue directly from the handler's mediaItems list —
        // the stream may not have emitted yet on first open.
        final queue = handler.queue.value;
        final currentIndex = handler.currentIndex;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Queue',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: queue.isEmpty
                      ? Center(
                          child: Text(
                            'Queue is empty',
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: queue.length,
                          itemBuilder: (context, index) {
                            final item = queue[index];
                            final isCurrent = index == currentIndex;
                            return ListTile(
                              leading: isCurrent
                                  ? Icon(Icons.equalizer,
                                      color: colorScheme.primary)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      isCurrent ? colorScheme.primary : null,
                                  fontWeight:
                                      isCurrent ? FontWeight.w600 : null,
                                ),
                              ),
                              subtitle: Text(
                                item.artist ?? 'Unknown Artist',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                handler.skipToQueueItem(index);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
