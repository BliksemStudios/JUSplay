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
    final queueAsync = ref.read(queueProvider);
    final queue = queueAsync.valueOrNull ?? [];
    final handler = ref.read(audioHandlerProvider);
    final currentIndex = handler.currentIndex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
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
