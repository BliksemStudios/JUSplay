import 'package:flutter_test/flutter_test.dart';
import 'package:jusplay/core/ai/playlist_generator.dart';

void main() {
  group('PlaylistGenerator', () {
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
