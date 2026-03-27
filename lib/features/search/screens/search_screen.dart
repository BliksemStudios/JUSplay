import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/audio/audio.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';

// -----------------------------------------------------------------------------
// Search state
// -----------------------------------------------------------------------------

class _SearchState {
  final SearchResult? result;
  final bool isLoading;
  final String? error;
  final String query;

  const _SearchState({
    this.result,
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  _SearchState copyWith({
    SearchResult? result,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return _SearchState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

// -----------------------------------------------------------------------------
// Search screen
// -----------------------------------------------------------------------------

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  _SearchState _state = const _SearchState();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _state = const _SearchState();
      });
      return;
    }

    setState(() {
      _state = _state.copyWith(query: query, isLoading: true);
    });

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final api = ref.read(subsonicApiProvider);
    if (api == null) {
      setState(() {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Not connected to a server',
        );
      });
      return;
    }

    try {
      final result = await api.search(
        query,
        artistCount: 5,
        albumCount: 5,
        songCount: 5,
      );
      if (mounted && _controller.text.trim() == query) {
        setState(() {
          _state = _state.copyWith(
            result: result,
            isLoading: false,
            error: null,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _state.copyWith(
            isLoading: false,
            error: e.toString(),
          );
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(subsonicApiProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Artists, albums, songs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                          _focusNode.requestFocus();
                        },
                      )
                    : null,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),

          // Content
          Expanded(
            child: api == null
                ? _buildNotConnected(colorScheme)
                : _buildContent(context, theme, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnected(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Not connected to a server',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Empty query -> show suggestions
    if (_state.query.isEmpty) {
      return _buildSuggestions(colorScheme);
    }

    // Loading
    if (_state.isLoading && _state.result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (_state.error != null && _state.result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Search failed',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final result = _state.result;
    if (result == null || result.isEmpty) {
      return _buildEmptyResults(colorScheme);
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            if (result.artists.isNotEmpty)
              _buildArtistsSection(context, theme, colorScheme, result.artists),
            if (result.albums.isNotEmpty)
              _buildAlbumsSection(context, theme, colorScheme, result.albums),
            if (result.songs.isNotEmpty)
              _buildSongsSection(context, theme, colorScheme, result.songs),
          ],
        ),
        if (_state.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildSuggestions(ColorScheme colorScheme) {
    final suggestions = [
      'Rock',
      'Jazz',
      'Classical',
      'Electronic',
      'Hip Hop',
      'Pop',
      'Metal',
      'Blues',
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search your library',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find artists, albums, and songs',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion),
                  onPressed: () {
                    _controller.text = suggestion;
                    _onQueryChanged(suggestion);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResults(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(
    BuildContext context,
    ThemeData theme,
    String title, {
    VoidCallback? onShowAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onShowAll != null)
            TextButton(
              onPressed: onShowAll,
              child: const Text('Show all'),
            ),
        ],
      ),
    );
  }

  Widget _buildArtistsSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<Artist> artists,
  ) {
    final api = ref.read(subsonicApiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          theme,
          'Artists',
          onShowAll: artists.length >= 5 ? () {} : null,
        ),
        ...artists.take(5).map((artist) {
          final artUrl = api?.coverArtUrl(artist.coverArtId, size: 80) ?? '';
          return ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.surfaceContainerHigh,
              backgroundImage:
                  artUrl.isNotEmpty ? CachedNetworkImageProvider(artUrl) : null,
              child: artUrl.isEmpty
                  ? Icon(Icons.person, color: colorScheme.onSurfaceVariant)
                  : null,
            ),
            title: Text(artist.name),
            subtitle: Text(
              '${artist.albumCount} album${artist.albumCount == 1 ? '' : 's'}',
            ),
            onTap: () => context.push('/artist/${artist.id}'),
          );
        }),
      ],
    );
  }

  Widget _buildAlbumsSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<Album> albums,
  ) {
    final api = ref.read(subsonicApiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          theme,
          'Albums',
          onShowAll: albums.length >= 5 ? () {} : null,
        ),
        ...albums.take(5).map((album) {
          final artUrl = api?.coverArtUrl(album.coverArtId, size: 80) ?? '';
          return ListTile(
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
                          child: Icon(Icons.album,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(Icons.album,
                              color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: Icon(Icons.album,
                            color: colorScheme.onSurfaceVariant),
                      ),
              ),
            ),
            title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              album.artistName ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => context.push('/album/${album.id}'),
          );
        }),
      ],
    );
  }

  Widget _buildSongsSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<Song> songs,
  ) {
    final api = ref.read(subsonicApiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          theme,
          'Songs',
          onShowAll: songs.length >= 5 ? () {} : null,
        ),
        ...songs.take(5).map((song) {
          final artUrl = api?.coverArtUrl(song.coverArtId, size: 80) ?? '';
          return ListTile(
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
                              color: colorScheme.onSurfaceVariant),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(Icons.music_note,
                              color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: Icon(Icons.music_note,
                            color: colorScheme.onSurfaceVariant),
                      ),
              ),
            ),
            title:
                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              song.artist ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatDuration(song.duration),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            onTap: () {
              if (api == null) return;
              final handler = ref.read(audioHandlerProvider);
              handler.playSong(
                song,
                streamUrl: api.streamUrl(song.id),
                coverArtUrl: api.coverArtUrl(song.coverArtId),
              );
            },
          );
        }),
      ],
    );
  }
}
