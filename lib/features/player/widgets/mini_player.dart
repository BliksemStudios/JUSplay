import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/audio/audio.dart';

/// A compact player bar that sits at the bottom of the screen.
///
/// Shows the current song's album art, title, artist, and a play/pause button.
/// Tapping the bar navigates to `/now-playing`. The widget is invisible when no
/// song is loaded (idle state).
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentSongProvider);
    final playbackAsync = ref.watch(playbackStateProvider);
    final positionAsync = ref.watch(positionProvider);
    final durationAsync = ref.watch(durationProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final mediaItem = mediaItemAsync.valueOrNull;
    final playbackState = playbackAsync.valueOrNull;
    final position = positionAsync.valueOrNull ?? Duration.zero;
    final duration = durationAsync.valueOrNull ?? Duration.zero;

    // Don't show when nothing is playing
    if (mediaItem == null || playbackState == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = playbackState.playing;
    final artUri = mediaItem.artUri;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => context.push('/now-playing'),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin progress indicator
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
            // Content row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: artUri != null
                          ? CachedNetworkImage(
                              imageUrl: artUri.toString(),
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  _placeholder(colorScheme),
                              errorWidget: (_, _, _) =>
                                  _placeholder(colorScheme),
                            )
                          : _placeholder(colorScheme),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mediaItem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mediaItem.artist ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Play / Pause button
                  IconButton(
                    onPressed: () {
                      final handler = ref.read(audioHandlerProvider);
                      if (isPlaying) {
                        handler.pause();
                      } else {
                        handler.play();
                      }
                    },
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHigh,
      child: Icon(Icons.music_note,
          size: 20, color: colorScheme.onSurfaceVariant),
    );
  }
}
