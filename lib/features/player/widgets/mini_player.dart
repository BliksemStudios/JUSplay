import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/audio/audio.dart';

/// A compact player bar that sits at the bottom of the screen.
///
/// Shows album art, title, artist, and prev/play-pause/next controls.
/// Tapping the art or song info navigates to `/now-playing`.
/// Returns [SizedBox.shrink] when nothing is loaded.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(currentSongProvider).valueOrNull;
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;

    if (mediaItem == null || playbackState == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = playbackState.playing;
    final colorScheme = Theme.of(context).colorScheme;
    final artUri = mediaItem.artUri;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: colorScheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin progress bar
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: Colors.transparent,
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                // Art — tappable to open now-playing
                GestureDetector(
                  onTap: () => context.push('/now-playing'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: artUri != null
                          ? CachedNetworkImage(
                              imageUrl: artUri.toString(),
                              fit: BoxFit.cover,
                              placeholder: (_, _) => _placeholder(colorScheme),
                              errorWidget: (_, _, _) =>
                                  _placeholder(colorScheme),
                            )
                          : _placeholder(colorScheme),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Song info — tappable to open now-playing
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/now-playing'),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mediaItem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
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
                ),

                // Controls: prev | play-pause | next
                _ControlButton(
                  icon: Icons.skip_previous,
                  onPressed: () => ref.read(audioHandlerProvider).skipToPrevious(),
                ),
                _ControlButton(
                  icon: isPlaying ? Icons.pause : Icons.play_arrow,
                  iconSize: 28,
                  onPressed: () {
                    final handler = ref.read(audioHandlerProvider);
                    if (isPlaying) {
                      handler.pause();
                    } else {
                      handler.play();
                    }
                  },
                ),
                _ControlButton(
                  icon: Icons.skip_next,
                  onPressed: () => ref.read(audioHandlerProvider).skipToNext(),
                ),
              ],
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

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 24,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
