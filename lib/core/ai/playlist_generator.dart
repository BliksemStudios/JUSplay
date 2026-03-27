import 'dart:convert';
import 'dart:io';
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

  /// Builds the Gemini prompt string.
  static String buildPrompt({
    required String userRequest,
    required List<String> genres,
    required List<String> artists,
    required List<String> songLines,
  }) {
    return '''You are a music curator. Given the user\'s library below, select up to 25 song IDs that best match the request. IMPORTANT: Ensure artist diversity — pick no more than 3 songs from any single artist. Spread picks across many different artists. Return ONLY a valid JSON array of song ID strings.

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
    void Function(String status)? onStatus,
  }) async {
    // 1. Try on-device AI (iOS Foundation Models)
    final nativeResult = await _tryNativeAi(userRequest, allSongs, onStatus);
    if (nativeResult != null && nativeResult.isNotEmpty) {
      return (songs: nativeResult, source: AiSource.onDevice);
    }

    // 2. Try cloud AI (Gemini) if API key is configured — multi-step like on-device
    if (geminiApiKey.isNotEmpty) {
      return _generateWithGeminiMultiStep(userRequest, allSongs, onStatus);
    }

    // 3. Fall back to smart algorithmic matching (works offline, no key)
    onStatus?.call('Building smart playlist…');
    final result = _generateSmart(userRequest, allSongs, onStatus);
    if (result.isNotEmpty) {
      return (songs: result, source: AiSource.smart);
    }

    throw PlaylistGenerationException(
      'Could not generate a playlist. Try a different description.',
    );
  }

  // ---------------------------------------------------------------------------
  // On-device AI: multi-step approach
  // ---------------------------------------------------------------------------

  Future<List<Song>?> _tryNativeAi(
    String userRequest,
    List<Song> allSongs,
    void Function(String status)? onStatus,
  ) async {
    try {
      // Step 1: Get genres from the library
      onStatus?.call('Matching genres to your vibe…');
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
      onStatus?.call('Filtering songs by genre…');
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

      onStatus?.call('Curating your playlist…');
      for (var b = 0; b < batches.length; b++) {
        onStatus?.call('Evaluating songs… (${b + 1}/${batches.length})');
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

      return _enforceArtistDiversity(allPicks);
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
  // Smart algorithmic fallback (no AI / no API key needed)
  // ---------------------------------------------------------------------------

  /// Keyword → genre mapping for common mood/activity requests.
  static const _moodGenres = <String, List<String>>{
    'workout': ['Metal', 'Hard Rock', 'Hip-Hop', 'EDM', 'Punk', 'Drum and Bass'],
    'gym': ['Metal', 'Hard Rock', 'Hip-Hop', 'EDM', 'Punk', 'Drum and Bass'],
    'exercise': ['Metal', 'Hard Rock', 'Hip-Hop', 'EDM', 'Punk'],
    'running': ['EDM', 'Hip-Hop', 'Pop', 'Drum and Bass', 'Trance'],
    'chill': ['Jazz', 'Lo-Fi', 'Ambient', 'Soul', 'R&B', 'Acoustic', 'Indie'],
    'relax': ['Jazz', 'Lo-Fi', 'Ambient', 'Classical', 'Acoustic', 'New Age'],
    'sleep': ['Ambient', 'Classical', 'New Age', 'Lo-Fi'],
    'study': ['Lo-Fi', 'Ambient', 'Classical', 'Jazz', 'Post-Rock'],
    'focus': ['Lo-Fi', 'Ambient', 'Classical', 'Electronic', 'Post-Rock'],
    'party': ['Pop', 'EDM', 'Hip-Hop', 'Dance', 'Reggaeton', 'House'],
    'dance': ['EDM', 'Pop', 'Dance', 'House', 'Disco', 'Techno'],
    'road trip': ['Rock', 'Classic Rock', 'Pop', 'Country', 'Indie'],
    'drive': ['Rock', 'Classic Rock', 'Pop', 'Hip-Hop', 'Electronic'],
    'sad': ['Blues', 'Ballad', 'Acoustic', 'Indie', 'Singer-Songwriter'],
    'melancholy': ['Blues', 'Ballad', 'Acoustic', 'Post-Rock', 'Shoegaze'],
    'happy': ['Pop', 'Reggae', 'Funk', 'Soul', 'Ska'],
    'energetic': ['Rock', 'Metal', 'Punk', 'EDM', 'Hip-Hop'],
    'aggressive': ['Metal', 'Heavy Metal', 'Thrash Metal', 'Hardcore', 'Punk'],
    'romantic': ['R&B', 'Soul', 'Jazz', 'Ballad', 'Pop'],
    'morning': ['Pop', 'Indie', 'Acoustic', 'Folk', 'Jazz'],
    'evening': ['Jazz', 'Soul', 'Lo-Fi', 'R&B', 'Ambient'],
    'dinner': ['Jazz', 'Soul', 'Classical', 'Bossa Nova', 'Acoustic'],
    'cooking': ['Jazz', 'Funk', 'Soul', 'Pop', 'Reggae'],
    'gaming': ['Metal', 'Electronic', 'EDM', 'Synthwave', 'Drum and Bass'],
    'coding': ['Lo-Fi', 'Electronic', 'Ambient', 'Post-Rock', 'Synthwave'],
    'rock': ['Rock', 'Classic Rock', 'Hard Rock', 'Alternative', 'Indie Rock'],
    'metal': ['Metal', 'Heavy Metal', 'Thrash Metal', 'Death Metal', 'Nu Metal'],
    'jazz': ['Jazz', 'Smooth Jazz', 'Bebop', 'Fusion'],
    'hip hop': ['Hip-Hop', 'Rap', 'Trap', 'R&B'],
    'rap': ['Hip-Hop', 'Rap', 'Trap'],
    'classical': ['Classical', 'Orchestral', 'Chamber Music'],
    'country': ['Country', 'Americana', 'Folk', 'Bluegrass'],
    'electronic': ['Electronic', 'EDM', 'House', 'Techno', 'Trance'],
    'pop': ['Pop', 'Synth-Pop', 'Indie Pop', 'K-Pop'],
    'blues': ['Blues', 'Delta Blues', 'Electric Blues'],
    'folk': ['Folk', 'Acoustic', 'Singer-Songwriter', 'Americana'],
    'punk': ['Punk', 'Pop Punk', 'Post-Punk', 'Hardcore'],
    'reggae': ['Reggae', 'Ska', 'Dub'],
    'soul': ['Soul', 'R&B', 'Funk', 'Motown'],
    'indie': ['Indie', 'Indie Rock', 'Indie Pop', 'Alternative'],
  };

  List<Song> _generateSmart(
    String userRequest,
    List<Song> allSongs,
    void Function(String status)? onStatus,
  ) {
    final requestLower = userRequest.toLowerCase();
    final words = requestLower.split(RegExp(r'\s+'));

    // Score each song based on keyword matches
    onStatus?.call('Analyzing your music library…');
    final scores = <Song, double>{};

    // Find which genre keywords match the request
    final targetGenres = <String>{};
    for (final entry in _moodGenres.entries) {
      if (requestLower.contains(entry.key)) {
        targetGenres.addAll(entry.value.map((g) => g.toLowerCase()));
      }
    }

    // Also match raw words against genres directly
    final allGenres = allSongs
        .map((s) => s.genre)
        .whereType<String>()
        .toSet();
    for (final genre in allGenres) {
      final genreLower = genre.toLowerCase();
      for (final word in words) {
        if (word.length >= 3 && genreLower.contains(word)) {
          targetGenres.add(genreLower);
        }
      }
    }

    onStatus?.call('Matching songs to your vibe…');
    for (final song in allSongs) {
      var score = 0.0;
      final genre = (song.genre ?? '').toLowerCase();
      final artist = (song.artist ?? '').toLowerCase();
      final title = song.title.toLowerCase();

      // Genre match (strongest signal)
      if (targetGenres.isNotEmpty && targetGenres.contains(genre)) {
        score += 10.0;
      }

      // Artist name in request (lower weight to avoid artist-heavy lists)
      if (artist.isNotEmpty) {
        for (final word in words) {
          if (word.length >= 3 && artist.contains(word)) {
            score += 3.0;
            break;
          }
        }
      }

      // Title keyword match
      for (final word in words) {
        if (word.length >= 3 && title.contains(word)) {
          score += 2.0;
          break;
        }
      }

      // Small random jitter for variety
      score += Random().nextDouble() * 2.0;

      if (score > 0) {
        scores[song] = score;
      }
    }

    // If no matches at all, do genre-weighted random
    if (scores.isEmpty && allSongs.isNotEmpty) {
      onStatus?.call('Picking a mix for you…');
      final shuffled = List.of(allSongs)..shuffle(Random());
      return shuffled.take(25).toList();
    }

    // Sort by score descending, then pick with artist diversity cap
    onStatus?.call('Finalizing your playlist…');
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _enforceArtistDiversity(sorted.map((e) => e.key).toList());
  }

  // ---------------------------------------------------------------------------
  // Gemini: single-shot approach (large context window)
  // ---------------------------------------------------------------------------

  /// Preferred model name prefixes, best first.
  static const _modelPreference = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-2.5-pro',
    'gemini-2.0-pro',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  /// Calls the Gemini REST API to list models available for this key,
  /// then picks the best one that supports generateContent.
  Future<String> _pickBestGeminiModel() async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$geminiApiKey',
      );
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);

      final json = jsonDecode(body) as Map<String, dynamic>;
      final models = (json['models'] as List?) ?? [];

      // Collect model names that support generateContent
      final available = <String>{};
      for (final m in models) {
        final name = (m['name'] as String?)?.replaceFirst('models/', '') ?? '';
        final methods = (m['supportedGenerationMethods'] as List?) ?? [];
        if (methods.contains('generateContent') && name.isNotEmpty) {
          available.add(name);
        }
      }

      print('[AI] Available Gemini models: $available');

      // Pick the best by preference order
      for (final preferred in _modelPreference) {
        // Exact match first
        if (available.contains(preferred)) return preferred;
        // Prefix match (e.g. "gemini-2.0-flash" matches "gemini-2.0-flash-001")
        final match = available.where((m) => m.startsWith(preferred)).firstOrNull;
        if (match != null) return match;
      }

      // If none from our preference list, just use the first available
      if (available.isNotEmpty) return available.first;
    } catch (e) {
      print('[AI] Failed to list models: $e');
    }

    // Fallback if API call fails
    return 'gemini-2.0-flash';
  }

  /// Gemini multi-step: same strategy as on-device but with larger batches (50).
  Future<({List<Song> songs, AiSource source})> _generateWithGeminiMultiStep(
    String userRequest,
    List<Song> allSongs,
    void Function(String status)? onStatus,
  ) async {
    final modelName = await _pickBestGeminiModel();
    print('[AI] Using Gemini model: $modelName');
    final model = GenerativeModel(model: modelName, apiKey: geminiApiKey);

    Future<String?> callGemini(String prompt) async {
      try {
        final resp = await model.generateContent([Content.text(prompt)]);
        return resp.text;
      } catch (e) {
        print('[AI] Gemini call failed: $e');
        return null;
      }
    }

    // Step 1: Genre matching
    onStatus?.call('Matching genres to your vibe…');
    final genreSongs = <String, List<Song>>{};
    for (final s in allSongs) {
      final g = s.genre ?? 'Unknown';
      (genreSongs[g] ??= []).add(s);
    }
    final genreList = genreSongs.keys.toList();
    if (genreList.isEmpty) {
      throw PlaylistGenerationException('No genres found in library.');
    }

    final genrePrompt =
        'A user wants music for: "$userRequest"\n\n'
        'Available genres: ${genreList.join(", ")}\n\n'
        'Which genres fit best? Reply with ONLY a JSON array of genre names, like ["Rock","Jazz"].';

    final genreResponse = await callGemini(genrePrompt);
    final matchedGenres = genreResponse != null ? parseResponse(genreResponse) : <String>[];
    print('[AI] Gemini Step 1 - matched genres: $matchedGenres');

    // Step 2: Filter songs by matched genres
    onStatus?.call('Filtering songs by genre…');
    List<Song> candidates;
    if (matchedGenres.isNotEmpty) {
      final matchedLower = matchedGenres.map((g) => g.toLowerCase()).toSet();
      candidates = allSongs.where((s) => matchedLower.contains((s.genre ?? '').toLowerCase())).toList();
    } else {
      candidates = List.of(allSongs);
    }
    if (candidates.isEmpty) candidates = List.of(allSongs);
    candidates.shuffle(Random());

    // Step 3: Batched evaluation — 50 songs per batch for Gemini's larger context
    final allPicks = <Song>[];
    const batchSize = 50;
    final batches = <List<Song>>[];
    for (var i = 0; i < candidates.length; i += batchSize) {
      batches.add(candidates.sublist(i, (i + batchSize > candidates.length) ? candidates.length : i + batchSize));
    }
    print('[AI] Gemini Step 2 - ${candidates.length} candidates in ${batches.length} batches');

    onStatus?.call('Curating your playlist…');
    for (var b = 0; b < batches.length; b++) {
      onStatus?.call('Evaluating songs… (${b + 1}/${batches.length})');
      final batch = batches[b];
      final songLines = <String>[];
      for (var i = 0; i < batch.length; i++) {
        songLines.add('${i + 1}. ${batch[i].title} by ${batch[i].artist ?? "Unknown"}');
      }

      final songPrompt =
          'Pick the best songs for "$userRequest" from this list. '
          'Ensure artist diversity — no more than 3 songs from any single artist.\n\n'
          '${songLines.join("\n")}\n\n'
          'Reply with ONLY the song numbers as a JSON array, like [1,3,5]. Pick all that fit the mood.';

      final songResponse = await callGemini(songPrompt);
      if (songResponse == null) continue;

      final pickedNumbers = parseNumberResponse(songResponse);
      print('[AI] Gemini Batch ${b + 1}/${batches.length} - picked: $pickedNumbers');

      final batchPicks = pickedNumbers
          .where((n) => n >= 1 && n <= batch.length)
          .map((n) => batch[n - 1]);
      allPicks.addAll(batchPicks);

      if (allPicks.length >= 25) break;
    }

    if (allPicks.isEmpty) {
      return (songs: candidates.take(15).toList(), source: AiSource.gemini);
    }

    return (songs: _enforceArtistDiversity(allPicks), source: AiSource.gemini);
  }

  /// Caps songs per artist to ensure diverse playlists across all AI sources,
  /// then shuffles to avoid artist clustering.
  static List<Song> _enforceArtistDiversity(List<Song> songs, {int maxPerArtist = 3, int maxTotal = 25}) {
    final picks = <Song>[];
    final artistCount = <String, int>{};
    for (final song in songs) {
      if (picks.length >= maxTotal) break;
      final artist = (song.artist ?? 'Unknown').toLowerCase();
      final count = artistCount[artist] ?? 0;
      if (count < maxPerArtist) {
        picks.add(song);
        artistCount[artist] = count + 1;
      }
    }
    picks.shuffle(Random());
    return picks;
  }
}

enum AiSource { onDevice, gemini, smart }

class PlaylistGenerationException implements Exception {
  const PlaylistGenerationException(this.message);
  final String message;

  @override
  String toString() => 'PlaylistGenerationException: $message';
}
