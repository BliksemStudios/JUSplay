import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

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
    );
  }
}

