import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/server_login_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/library/screens/library_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/playlists/screens/playlists_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/player/screens/now_playing_screen.dart';
import '../features/library/screens/artist_detail_screen.dart';
import '../features/library/screens/album_detail_screen.dart';
import '../features/playlists/screens/playlist_detail_screen.dart';

// TODO: Replace with actual auth state provider once implemented
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated) {
        return isLoginRoute ? null : '/login';
      }

      if (isLoginRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          if (!isAuthenticated) return '/login';
          return '/home';
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const ServerLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ScaffoldWithNavBar(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryScreen(),
            ),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: '/playlists',
            name: 'playlists',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlaylistsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/artist/:id',
        name: 'artist-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ArtistDetailScreen(artistId: id);
        },
      ),
      GoRoute(
        path: '/album/:id',
        name: 'album-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AlbumDetailScreen(albumId: id);
        },
      ),
      GoRoute(
        path: '/playlist/:id',
        name: 'playlist-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PlaylistDetailScreen(playlistId: id);
        },
      ),
      GoRoute(
        path: '/now-playing',
        name: 'now-playing',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NowPlayingScreen(),
          fullscreenDialog: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            );
          },
        ),
      ),
    ],
  );
});

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _navItems = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home', path: '/home'),
    _NavItem(icon: Icons.library_music_outlined, selectedIcon: Icons.library_music, label: 'Library', path: '/library'),
    _NavItem(icon: Icons.search_outlined, selectedIcon: Icons.search, label: 'Search', path: '/search'),
    _NavItem(icon: Icons.queue_music_outlined, selectedIcon: Icons.queue_music, label: 'Playlists', path: '/playlists'),
    _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings', path: '/settings'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          context.go(_navItems[index].path);
        },
        destinations: _navItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
}
