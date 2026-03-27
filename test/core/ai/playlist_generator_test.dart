import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jusplay/core/ai/playlist_generator.dart';
import 'package:jusplay/core/models/song.dart';

void main() {
  group('PlaylistGenerator', () {
    group('generate', () {
      test('falls back to smart matching when API key is empty and on-device unavailable', () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        // Mock channel to return null (on-device AI unavailable)
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.bliksemstudios.jusplay/ai'),
          (call) async => null,
        );

        final generator = PlaylistGenerator(geminiApiKey: '');
        final songs = [
          const Song(id: 'id1', title: 'Chill Vibes', duration: 180, genre: 'Jazz'),
        ];

        final result = await generator.generate(
          userRequest: 'jazz',
          allSongs: songs,
        );

        // Smart fallback should return results, not throw
        expect(result.source, AiSource.smart);
        expect(result.songs, isNotEmpty);
      });

      test('filters out song IDs not in allSongs', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Mock channel returns null (on-device unavailable)
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.bliksemstudios.jusplay/ai'),
          (call) async => null,
        );

        final generator = PlaylistGenerator(geminiApiKey: '');
        final songs = [
          const Song(id: 'id1', title: 'Rock Song', duration: 180, genre: 'Rock'),
        ];

        final result = await generator.generate(
          userRequest: 'rock',
          allSongs: songs,
        );

        // All returned songs should be from allSongs
        for (final song in result.songs) {
          expect(songs.map((s) => s.id), contains(song.id));
        }
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

      test('filters non-string elements from mixed array', () {
        final ids = PlaylistGenerator.parseResponse('[1,"id2",null]');
        expect(ids, ['id2']);
      });
    });
  });
}
