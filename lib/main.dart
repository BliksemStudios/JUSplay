import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/audio/audio.dart';
import 'core/cache/cache.dart';
import 'core/providers/providers.dart';
import 'core/storage/storage.dart';

void main() async {
  // Catch ALL uncaught errors to prevent silent crashes
  FlutterError.onError = (details) {
    print('[JUSPlay] FLUTTER ERROR: ${details.exception}');
    print('[JUSPlay] STACK: ${details.stack}');
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Hive.initFlutter();

    final serverStorage = ServerStorage();
    await serverStorage.init();

    final settingsStorage = SettingsStorage();
    await settingsStorage.init();

    final cacheManager = CacheManager(
      storage: CacheStorage(),
      settings: settingsStorage,
      dio: Dio(),
    );
    await cacheManager.init();

    final audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.bliksemstudios.jusplay.audio',
        androidNotificationChannelName: 'JUSPlay',
        androidNotificationOngoing: true,
      ),
    );

    runApp(
      ProviderScope(
        overrides: [
          serverStorageProvider.overrideWithValue(serverStorage),
          settingsStorageProvider.overrideWithValue(settingsStorage),
          audioHandlerProvider.overrideWithValue(audioHandler),
          cacheManagerProvider.overrideWithValue(cacheManager),
        ],
        child: const JUSPlayApp(),
      ),
    );
  }, (error, stack) {
    print('[JUSPlay] UNCAUGHT ERROR: $error');
    print('[JUSPlay] STACK: $stack');
  });
}
