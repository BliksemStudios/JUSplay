import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/playlist_generator.dart';
import '../../../core/ai/playlist_presets.dart';
import '../../../core/audio/audio.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../player/widgets/mini_player.dart';

// Provider: all songs from library (for the AI to pick from)
// Uses search3 with empty query and high songCount to get a broad list.
final _allSongsProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final api = ref.watch(subsonicApiProvider);
  if (api == null) return [];
  final result = await api.search('', songCount: 500);
  return result.songs;
});

class SmartPlaylistScreen extends ConsumerStatefulWidget {
  const SmartPlaylistScreen({super.key, this.initialPrompt = ''});
  final String initialPrompt;

  @override
  ConsumerState<SmartPlaylistScreen> createState() =>
      _SmartPlaylistScreenState();
}

class _SmartPlaylistScreenState extends ConsumerState<SmartPlaylistScreen> {
  late final TextEditingController _controller;
  List<Song>? _result;
  AiSource? _source;
  bool _loading = false;
  String? _error;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrompt);
    // Don't auto-generate — let the user review/edit the prompt first.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _statusText = 'Loading your music library…';
    });

    try {
      final allSongs = await ref.read(_allSongsProvider.future);
      _setStatus('Analysing your library…');

      final apiKey = ref.read(settingsStorageProvider).geminiApiKey;
      final generator = PlaylistGenerator(geminiApiKey: apiKey);
      final (:songs, :source) = await generator.generate(
        userRequest: prompt,
        allSongs: allSongs,
        onStatus: _setStatus,
      );
      if (mounted) {
        setState(() {
          _result = songs;
          _source = source;
          _loading = false;
        });
      }
    } on PlaylistGenerationException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveAsPlaylist(List<Song> songs) async {
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;

    final nameController = TextEditingController(
      text: _controller.text.trim(),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Save as Playlist'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(dialogCtx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    try {
      await api.createPlaylist(
        name: name,
        songIds: songs.map((s) => s.id).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "$name" with ${songs.length} songs')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _playAll(List<Song> songs) {
    if (songs.isEmpty) return;
    final api = ref.read(subsonicApiProvider);
    if (api == null) return;
    final handler = ref.read(audioHandlerProvider);
    handler.playQueue(
      songs,
      startIndex: 0,
      getStreamUrl: (id) => api.streamUrl(id),
      getCoverArtUrl: (id) => api.coverArtUrl(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Playlist')),
      bottomNavigationBar: const MiniPlayer(standalone: true),
      body: Column(
        children: [
          // Input area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Describe what you want to listen to…',
                    ),
                    onSubmitted: (_) => _generate(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _generate,
                  child: const Text('Go'),
                ),
              ],
            ),
          ),
          // Preset chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: smartPlaylistPresetCount,
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(smartPlaylistLabels[i]),
                    onPressed: () {
                      _controller.text = randomPresetPrompt(i);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Results
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _statusText,
                key: ValueKey(_statusText),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      );
    }
    if (_result == null) {
      return Center(
        child: Text(
          'Describe your mood or pick a vibe above',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final songs = _result!;
    return Column(
      children: [
        // Privacy badge + play all
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _PrivacyBadge(source: _source!),
              const Spacer(),
              Text(
                '${songs.length} songs',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _saveAsPlaylist(songs),
                icon: const Icon(Icons.save_alt),
                tooltip: 'Save as playlist',
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => _playAll(songs),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Play All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) => _SongTile(
              song: songs[i],
              index: i,
              songs: songs,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.source});
  final AiSource source;

  @override
  Widget build(BuildContext context) {
    final isOnDevice = source == AiSource.onDevice;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOnDevice ? '🔒 On-device' : '☁️ Gemini',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _SongTile extends ConsumerWidget {
  const _SongTile({
    required this.song,
    required this.index,
    required this.songs,
  });

  final Song song;
  final int index;
  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(subsonicApiProvider);
    final coverUrl = api?.coverArtUrl(song.coverArtId, size: 100) ?? '';
    final theme = Theme.of(context);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 44,
          height: 44,
          child: coverUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (context2, url) => Container(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: const Icon(Icons.music_note, size: 20),
                  ),
                  errorWidget: (context2, url, err) => Container(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: const Icon(Icons.music_note, size: 20),
                  ),
                )
              : Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: const Icon(Icons.music_note, size: 20),
                ),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.artist ?? 'Unknown Artist',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      onTap: () {
        if (api == null) return;
        final handler = ref.read(audioHandlerProvider);
        handler.playQueue(
          songs,
          startIndex: index,
          getStreamUrl: (id) => api.streamUrl(id),
          getCoverArtUrl: (id) => api.coverArtUrl(id),
        );
      },
    );
  }
}
