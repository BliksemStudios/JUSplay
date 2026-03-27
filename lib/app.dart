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
      darkTheme: AppTheme.forAccent(themeKey),
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
  static const _shellRoutes = {'/home', '/library', '/search', '/settings'};
  static const _navBarHeight = 80.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);

    if (_hiddenRoutes.contains(location)) {
      return const SizedBox.shrink();
    }

    final isShellRoute = _shellRoutes.any((r) => location.startsWith(r));
    final bottomPadding = MediaQuery.of(context).padding.bottom +
        (isShellRoute ? _navBarHeight : 0.0);

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPadding,
      child: const MiniPlayer(),
    );
  }
}
