import 'dart:math';

final _rng = Random();

/// Each preset has a label and a list of prompt variations.
/// [randomPresetPrompt] picks one at random for freshness.
const _presets = <(String, List<String>)>[
  ('Workout 💪', [
    'high energy workout bangers',
    'intense gym motivation tracks',
    'powerful training anthems to push through',
    'adrenaline-pumping exercise songs',
  ]),
  ('Focus 🎯', [
    'instrumental focus music for deep work',
    'concentration-boosting ambient tracks',
    'calm background music for studying',
    'minimal distraction productivity tunes',
  ]),
  ('Chill 😌', [
    'relaxing chill vibes to unwind',
    'laid-back easy listening songs',
    'mellow downtempo tracks for a lazy afternoon',
    'smooth and soothing background music',
  ]),
  ('Party 🎉', [
    'upbeat party anthems to get everyone moving',
    'high energy dance floor bangers',
    'feel-good crowd-pleasing hits',
    'songs that make you want to dance',
  ]),
  ('Sad hours 🌧', [
    'melancholic emotional songs for a rainy day',
    'heartfelt ballads and sad vibes',
    'moody introspective tracks',
    'songs that hit you right in the feels',
  ]),
  ('Road trip 🚗', [
    'road trip driving songs with the windows down',
    'open highway adventure anthems',
    'feel-good cruising music for long drives',
    'sing-along tracks for the open road',
  ]),
  ('Sleep 🌙', [
    'calm sleep music to drift off to',
    'gentle lullaby-like ambient sounds',
    'peaceful and quiet bedtime tracks',
    'soft dreamy music for falling asleep',
  ]),
  ('Morning coffee ☕', [
    'light acoustic morning songs to start the day',
    'warm and sunny wake-up tunes',
    'gentle uplifting tracks for a slow morning',
    'easygoing coffeehouse vibes',
  ]),
];

/// The chip labels for display.
List<String> get smartPlaylistLabels =>
    _presets.map((p) => p.$1).toList();

/// Returns a random prompt variation for the given chip index.
String randomPresetPrompt(int index) =>
    _presets[index].$2[_rng.nextInt(_presets[index].$2.length)];

/// Number of presets available.
int get smartPlaylistPresetCount => _presets.length;

/// Legacy accessor — returns all presets as (label, randomPrompt) pairs.
List<(String, String)> get smartPlaylistPresets =>
    List.generate(_presets.length, (i) => (_presets[i].$1, randomPresetPrompt(i)));
