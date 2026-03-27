import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/models.dart';

/// Orchestrates AI-powered playlist generation.
///
/// On-device (iOS Foundation Models): uses a multi-step approach —
///   1. AI picks genres matching the user's mood
///   2. Dart filters songs by those genres
///   3. AI picks songs from a small numbered list
///
/// Cloud (Gemini): single-shot prompt with full library data.
class PlaylistGenerator {
  PlaylistGenerator({required this.geminiApiKey});

  final String geminiApiKey;

  static const _methodChannel =
      MethodChannel('com.bliksemstudios.jusplay/ai');

  static const int _maxSongLines = 500;
  static const int _maxArtists = 100;

  /// Builds the Gemini prompt string.
  static String buildPrompt({
    required String userRequest,
    required List<String> genres,
    required List<String> artists,
    required List<String> songLines,
  }) {
    return '''You are a music curator. Given the user\'s library below, select up to 25 song IDs that best match the request. Return ONLY a valid JSON array of song ID strings.

Library genres: ${genres.join(', ')}
Artists: ${artists.join(', ')}
Songs (id|title|artist|genre|duration_secs):
${songLines.join('\n')}

User request: "$userRequest"

Response format: ["id1","id2","id3"]''';
  }

  /// Parses a JSON array from AI response text.
  static List<String> parseResponse(String response) {
    try {
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(response.trim());
      if (match == null) return [];
      final decoded = jsonDecode(match.group(0)!);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((id) => id.replaceAll(RegExp(r'[\[\]]'), '').trim())
            .where((id) => id.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Parses a JSON array of integers from AI response text.
  static List<int> parseNumberResponse(String response) {
    try {
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(response.trim());
      if (match == null) return [];
      final decoded = jsonDecode(match.group(0)!);
      if (decoded is List) {
        return decoded.map((e) {
          if (e is int) return e;
          if (e is String) return int.tryParse(e);
          return null;
        }).whereType<int>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<({List<Song> songs, AiSource source})> generate({
    required String userRequest,
    required List<Song> allSongs,
  }) async {
    final nativeResult = await _tryNativeAi(userRequest, allSongs);
    if (nativeResult != null && nativeResult.isNotEmpty) {
      return (songs: nativeResult, source: AiSource.onDevice);
    }

    if (geminiApiKey.isEmpty) {
      throw PlaylistGenerationException(
        'No AI available. Add a Gemini API key in Settings → AI Features.',
      );
    }

    return _generateWithGemini(userRequest, allSongs);
  }

  // ---------------------------------------------------------------------------
  // On-device AI: multi-step approach
  // ---------------------------------------------------------------------------

  Future<List<Song>?> _tryNativeAi(
    String userRequest,
    List<Song> allSongs,
  ) async {
    try {
      // Step 1: Get genres from the library
      final genreSongs = <String, List<Song>>{};
      for (final s in allSongs) {
        final g = s.genre ?? 'Unknown';
        (genreSongs[g] ??= []).add(s);
      }
      final genreList = genreSongs.keys.toList();

      if (genreList.isEmpty) return null;

      // Step 1: Ask AI which genres match the mood
      final genrePrompt =
          'A user wants music for: "$userRequest"\n\n'
          'Available genres: ${genreList.join(", ")}\n\n'
          'Which genres fit best? Reply with ONLY a JSON array of genre names, like ["Rock","Jazz"].';

      final genreResponse = await _callNativeAi(genrePrompt);
      if (genreResponse == null) return null;

      final matchedGenres = parseResponse(genreResponse);
      print('[AI] Step 1 - matched genres: $matchedGenres');

      // Step 2: Filter songs by matched genres, with fallback
      List<Song> candidates;
      if (matchedGenres.isNotEmpty) {
        final matchedLower = matchedGenres.map((g) => g.toLowerCase()).toSet();
        candidates = allSongs
            .where((s) => matchedLower.contains((s.genre ?? '').toLowerCase()))
            .toList();
      } else {
        candidates = List.of(allSongs);
      }

      if (candidates.isEmpty) {
        candidates = List.of(allSongs);
      }

      // Shuffle candidates for variety
      candidates.shuffle(Random());

      // Step 3: Process ALL candidates in batches of 20
      // Each batch gets its own AI call to pick the best songs
      final allPicks = <Song>[];
      const batchSize = 20;
      final batches = <List<Song>>[];
      for (var i = 0; i < candidates.length; i += batchSize) {
        batches.add(candidates.sublist(
          i,
          (i + batchSize > candidates.length) ? candidates.length : i + batchSize,
        ));
      }

      print('[AI] Step 2 - ${candidates.length} candidates in ${batches.length} batches');

      for (var b = 0; b < batches.length; b++) {
        final batch = batches[b];
        final songLines = <String>[];
        for (var i = 0; i < batch.length; i++) {
          final s = batch[i];
          songLines.add('${i + 1}. ${s.title} by ${s.artist ?? "Unknown"}');
        }

        final songPrompt =
            'Pick the best songs for "$userRequest" from this list:\n\n'
            '${songLines.join("\n")}\n\n'
            'Reply with ONLY the song numbers as a JSON array, like [1,3,5]. '
            'Pick all that fit the mood.';

        final songResponse = await _callNativeAi(songPrompt);
        if (songResponse == null) continue;

        final pickedNumbers = parseNumberResponse(songResponse);
        print('[AI] Batch ${b + 1}/${batches.length} - picked: $pickedNumbers');

        final batchPicks = pickedNumbers
            .where((n) => n >= 1 && n <= batch.length)
            .map((n) => batch[n - 1]);
        allPicks.addAll(batchPicks);

        // Stop early if we have enough songs
        if (allPicks.length >= 25) break;
      }

      print('[AI] Total picks: ${allPicks.length}');

      if (allPicks.isEmpty) {
        // AI didn't pick anything — return genre-filtered sample
        return candidates.take(15).toList();
      }

      return allPicks.take(25).toList();
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      throw PlaylistGenerationException(
        'On-device AI error: ${e.message ?? e.code}',
      );
    }
  }

  /// Makes a single call to the on-device Foundation Models via method channel.
  Future<String?> _callNativeAi(String prompt) async {
    try {
      return await _methodChannel.invokeMethod<String>(
        'generatePlaylist',
        {'prompt': prompt, 'songList': ''},
      );
    } on MissingPluginException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Gemini: single-shot approach (large context window)
  // ---------------------------------------------------------------------------

  Future<({List<Song> songs, AiSource source})> _generateWithGemini(
    String userRequest,
    List<Song> allSongs,
  ) async {
    final genres = allSongs
        .map((s) => s.genre)
        .whereType<String>()
        .toSet()
        .toList();
    final artists = allSongs
        .map((s) => s.artist)
        .whereType<String>()
        .toSet()
        .take(_maxArtists)
        .toList();
    final songLines = allSongs.take(_maxSongLines).map((s) {
      return '${s.id}|${s.title}|${s.artist ?? ''}|${s.genre ?? ''}|${s.duration}';
    }).toList();

    final prompt = buildPrompt(
      userRequest: userRequest,
      genres: genres,
      artists: artists,
      songLines: songLines,
    );

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: geminiApiKey,
    );

    final content = [Content.text(prompt)];
    final GenerateContentResponse response;
    try {
      response = await model.generateContent(content);
    } catch (e) {
      throw PlaylistGenerationException('Gemini request failed: $e');
    }
    final text = response.text ?? '';

    final ids = parseResponse(text);
    if (ids.isEmpty) {
      throw PlaylistGenerationException(
        'AI returned an empty or invalid playlist.',
      );
    }

    final songMap = {for (final s in allSongs) s.id: s};
    final result = ids
        .map((id) => songMap[id])
        .whereType<Song>()
        .toList();

    return (songs: result, source: AiSource.gemini);
  }
}

enum AiSource { onDevice, gemini }

class PlaylistGenerationException implements Exception {
  const PlaylistGenerationException(this.message);
  final String message;

  @override
  String toString() => 'PlaylistGenerationException: $message';
}
