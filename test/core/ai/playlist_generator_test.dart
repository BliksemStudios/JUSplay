import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jusplay/core/ai/playlist_generator.dart';
import 'package:jusplay/core/models/song.dart';

void main() {
  group('PlaylistGenerator', () {
    group('generate', () {
      test('throws PlaylistGenerationException when API key is empty', () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        // Mock channel to return null (stub behavior)
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.bliksemstudios.jusplay/ai'),
          (call) async => null,
        );

        final generator = PlaylistGenerator(geminiApiKey: '');
        final songs = [
          const Song(id: 'id1', title: 'Song 1', duration: 180),
        ];

        expect(
          () => generator.generate(userRequest: 'chill', allSongs: songs),
          throwsA(isA<PlaylistGenerationException>()),
        );
      });

      test('returns onDevice source when native channel responds', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Return a valid JSON array from the channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.bliksemstudios.jusplay/ai'),
          (call) async => '["id1"]',
        );

        final generator = PlaylistGenerator(geminiApiKey: 'fake-key');
        final songs = [
          const Song(id: 'id1', title: 'Song 1', duration: 180),
          const Song(id: 'id2', title: 'Song 2', duration: 200),
        ];

        final result = await generator.generate(
          userRequest: 'something',
          allSongs: songs,
        );

        expect(result.source, AiSource.onDevice);
        expect(result.songs.length, 1);
        expect(result.songs.first.id, 'id1');
      });

      test('filters out song IDs not in allSongs', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.bliksemstudios.jusplay/ai'),
          (call) async => '["id1","unknown_id"]',
        );

        final generator = PlaylistGenerator(geminiApiKey: '');
        final songs = [
          const Song(id: 'id1', title: 'Song 1', duration: 180),
        ];

        final result = await generator.generate(
          userRequest: 'test',
          allSongs: songs,
        );

        expect(result.songs.length, 1); // unknown_id filtered out
        expect(result.songs.first.id, 'id1');
      });
    });

    group('buildPrompt', () {
      test('includes user request in output', () {
        final prompt = PlaylistGenerator.buildPrompt(
          userRequest: 'morning coffee vibes',
          genres: ['Jazz', 'Acoustic'],
          artists: ['Norah Jones', 'Jack Johnson'],
          songLines: ['id1|Coffee Morning|Norah Jones|Jazz|230'],
        );
        expect(prompt, contains('morning coffee vibes'));
        expect(prompt, contains('Jazz'));
        expect(prompt, contains('id1|Coffee Morning'));
      });
    });

    group('parseResponse', () {
      test('parses valid JSON array', () {
        final ids = PlaylistGenerator.parseResponse('["id1","id2","id3"]');
        expect(ids, ['id1', 'id2', 'id3']);
      });

      test('returns empty list for invalid JSON', () {
        final ids = PlaylistGenerator.parseResponse('not json');
        expect(ids, isEmpty);
      });

      test('returns empty list for empty response', () {
        final ids = PlaylistGenerator.parseResponse('');
        expect(ids, isEmpty);
      });

      test('handles JSON with surrounding whitespace', () {
        final ids = PlaylistGenerator.parseResponse('  ["a","b"]  ');
        expect(ids, ['a', 'b']);
      });
    });
  });
}
