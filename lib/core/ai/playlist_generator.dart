import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/models.dart';

/// Orchestrates AI-powered playlist generation.
///
/// Primary: Gemini API (cloud)
/// Secondary stub: iOS Foundation Models via method channel (returns null —
///   Gemini handles all calls until native implementation is added)
class PlaylistGenerator {
  PlaylistGenerator({required this.geminiApiKey});

  final String geminiApiKey;

  static const _methodChannel =
      MethodChannel('com.bliksemstudios.jusplay/ai');

  /// Builds the prompt string sent to the AI model.
  ///
  /// Exposed as a static method so it can be unit-tested without a live API key.
  static String buildPrompt({
    required String userRequest,
    required List<String> genres,
    required List<String> artists,
    required List<String> songLines, // each: "id|title|artist|genre|duration"
  }) {
    return '''You are a music curator. Given the user\'s library below, select up to 25 song IDs that best match the request. Return ONLY a valid JSON array of song ID strings.

Library genres: ${genres.join(', ')}
Artists: ${artists.join(', ')}
Songs (id|title|artist|genre|duration_secs):
${songLines.join('\n')}

User request: "$userRequest"

Response format: ["id1","id2","id3"]''';
  }

  /// Parses the AI response JSON into a list of song IDs.
  ///
  /// Returns an empty list if parsing fails.
  static List<String> parseResponse(String response) {
    try {
      final trimmed = response.trim();
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return [];
  }

  /// Generates a playlist from [allSongs] matching [userRequest].
  ///
  /// Returns the matching [Song] objects in recommended order.
  /// Throws [PlaylistGenerationException] on API failure.
  Future<({List<Song> songs, AiSource source})> generate({
    required String userRequest,
    required List<Song> allSongs,
  }) async {
    // Try iOS Foundation Models first (stub — always returns null for now)
    final nativeResult = await _tryNativeAi(userRequest, allSongs);
    if (nativeResult != null) {
      return (songs: nativeResult, source: AiSource.onDevice);
    }

    // Fall back to Gemini
    if (geminiApiKey.isEmpty) {
      throw PlaylistGenerationException(
        'No Gemini API key configured. Add one in Settings → AI Features.',
      );
    }

    final genres = allSongs
        .map((s) => s.genre)
        .whereType<String>()
        .toSet()
        .toList();
    final artists = allSongs
        .map((s) => s.artist)
        .whereType<String>()
        .toSet()
        .take(100)
        .toList();
    final songLines = allSongs.take(500).map((s) {
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
    final response = await model.generateContent(content);
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

  Future<List<Song>?> _tryNativeAi(
    String userRequest,
    List<Song> allSongs,
  ) async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'generatePlaylist',
        {'prompt': userRequest},
      );
      if (result == null) return null;
      final ids = parseResponse(result);
      final songMap = {for (final s in allSongs) s.id: s};
      return ids.map((id) => songMap[id]).whereType<Song>().toList();
    } on MissingPluginException {
      return null; // channel not registered on Android
    } on PlatformException {
      return null; // stub returns FlutterMethodNotImplemented
    }
  }
}

enum AiSource { onDevice, gemini }

class PlaylistGenerationException implements Exception {
  const PlaylistGenerationException(this.message);
  final String message;

  @override
  String toString() => 'PlaylistGenerationException: $message';
}
