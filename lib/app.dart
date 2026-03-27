import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'features/player/widgets/mini_player.dart';

class JUSPlayApp extends ConsumerWidget {
  const JUSPlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeKey = ref.watch(accentThemeProvider);

    return MaterialApp.router(
      title: 'JUSPlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forAccent(themeKey),
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const _GlobalMiniPlayer(),
          ],
        );
      },
    );
  }
}

/// Renders the MiniPlayer globally above every route.
/// Hidden on /login, /now-playing, and / (redirect root).
class _GlobalMiniPlayer extends ConsumerWidget {
  const _GlobalMiniPlayer();

  static const _hiddenRoutes = {'/login', '/now-playing', '/'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);

    if (_hiddenRoutes.contains(location)) {
      return const SizedBox.shrink();
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPadding,
      child: const MiniPlayer(),
    );
  }
}
