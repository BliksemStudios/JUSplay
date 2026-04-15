import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/audio/audio.dart';
import 'core/providers/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

/// One-shot provider that attempts to restore the saved playback queue on
/// startup. Depends on an active server (for URL resolution) and the audio
/// handler. Returns `true` if a queue was restored.
final _queueRestoreProvider = FutureProvider<bool>((ref) async {
  final api = ref.watch(subsonicApiProvider);
  final handler = ref.watch(audioHandlerProvider);
  if (api == null) return false;
  // Only restore if the queue is currently empty (fresh launch)
  if (handler.songQueue.isNotEmpty) return false;
  return handler.restoreQueueState(
    getStreamUrl: (id) => api.streamUrl(id),
    getCoverArtUrl: (id) => api.coverArtUrl(id, size: 600),
  );
});

class JUSPlayApp extends ConsumerWidget {
  const JUSPlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeKey = ref.watch(accentThemeProvider);

    // Eagerly initialise the CarPlay bridge (iOS only, no-op otherwise).
    ref.watch(carplayServiceProvider);

    // Eagerly initialise the Watch bridge (iOS only, no-op otherwise).
    ref.watch(watchServiceProvider);

    // Attempt queue restoration on startup (fire-and-forget).
    ref.watch(_queueRestoreProvider);

    return MaterialApp.router(
      title: 'JUSPlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forAccent(themeKey),
      darkTheme: AppTheme.forAccent(themeKey),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

