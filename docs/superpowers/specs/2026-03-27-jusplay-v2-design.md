# JUSPlay v2 Design Spec
**Date:** 2026-03-27
**Status:** Approved

---

## Overview

Five feature areas to implement in priority order:

1. Mini Player persistent shell fix (bug)
2. 4-theme system + themed app icons
3. Header/logo redesign
4. Lock screen audio controls (iOS Info.plist verification)
5. AI Smart Playlists (Gemini + Foundation Models stub)
6. Settings screen updates (theme picker + Gemini API key)

---

## 1. Mini Player Persistent Shell

### Problem
`MiniPlayer` lives inside `ScaffoldWithNavBar`, which is only rendered by the `ShellRoute`. Detail routes (`/album/:id`, `/artist/:id`, `/playlist/:id`) are top-level `GoRoute` instances outside the `ShellRoute` — `MiniPlayer` is not in the widget tree on those screens.

### Solution: Global Stack overlay in `lib/app.dart`

`JUSPlayApp` becomes a `ConsumerWidget` that stacks `MiniPlayer` above the router output:

```dart
// lib/app.dart
Stack(
  children: [
    MaterialApp.router(...),
    Positioned(
      left: 0, right: 0, bottom: 0,
      child: _ConditionalMiniPlayer(),
    ),
  ],
)
```

`_ConditionalMiniPlayer` watches the router's current location and returns `SizedBox.shrink()` when the route is `/login`, `/now-playing`, or `/` (redirect). All other routes show the player.

Route detection: `_ConditionalMiniPlayer` is outside `MaterialApp.router`'s widget tree, so `GoRouterState.of(context)` is unavailable. Instead, a `currentRouteProvider = StateProvider<String>((ref) => '/')` is updated by a `_RouteObserver extends NavigatorObserver` registered in the `GoRouter`'s `observers` list. The observer calls `ref.read(currentRouteProvider.notifier).state = route.settings.name` on `didPush`/`didPop`/`didReplace`. `_ConditionalMiniPlayer` watches `currentRouteProvider` via Riverpod.

**MiniPlayer bottom padding:** Must add `MediaQuery.of(context).padding.bottom` to the player container so it clears the home indicator on iPhone. Remove `const MiniPlayer()` from `ScaffoldWithNavBar` once global overlay is in place.

### Files changed
- `lib/app.dart` — Stack overlay + `_ConditionalMiniPlayer`
- `lib/core/router.dart` — add `NavigatorObserver`, expose `currentRouteProvider`; remove `MiniPlayer` from `ScaffoldWithNavBar`

---

## 2. Theme System — 4 Themes

### Themes

| Key | Display Name | Accent | Background | Surface |
|-----|-------------|--------|-----------|---------|
| `goldAmber` | Dark + Gold/Amber ⭐ | `#F59E0B` | `#0A0A0A` | `#1A1500` |
| `cyanTeal` | Dark + Cyan/Teal | `#06B6D4` | `#030A0A` | `#001515` |
| `coralOrange` | Dark + Coral/Orange | `#F97316` | `#0A0500` | `#1A0A00` |
| `oledWhite` | OLED + White | `#FFFFFF` | `#000000` | `#111111` |

Default: `goldAmber`

### Architecture

**`lib/core/theme/app_theme.dart`** — replace hardcoded purple with factory:

```dart
static ThemeData forAccent(String themeKey) {
  final config = _themes[themeKey] ?? _themes['goldAmber']!;
  // Returns full ThemeData with config.accent as primary,
  // config.background as scaffoldBackgroundColor,
  // config.surface as card/navigation background
}

static const Map<String, _ThemeConfig> _themes = { ... };
```

**`lib/core/storage/settings_storage.dart`** — add `accentTheme` key:
```dart
static const String _accentThemeKey = 'accent_theme';
String get accentTheme => _box.get(_accentThemeKey, defaultValue: 'goldAmber') as String;
Future<void> setAccentTheme(String value) => _box.put(_accentThemeKey, value);
```

**`lib/core/providers/api_provider.dart`** (or new `theme_provider.dart`) — `AccentThemeNotifier`:
```dart
class AccentThemeNotifier extends StateNotifier<String> {
  AccentThemeNotifier(this._settings) : super(_settings.accentTheme);
  Future<void> setTheme(String key) async {
    await _settings.setAccentTheme(key);
    state = key;
  }
}
final accentThemeProvider = StateNotifierProvider<AccentThemeNotifier, String>((ref) {
  return AccentThemeNotifier(ref.watch(settingsStorageProvider));
});
```

**`lib/app.dart`** — watch `accentThemeProvider`, pass to `MaterialApp.router`:
```dart
final themeKey = ref.watch(accentThemeProvider);
return MaterialApp.router(
  theme: AppTheme.forAccent(themeKey),
  themeMode: ThemeMode.dark,
  ...
);
```

### App Icons Per Theme

Generate 4 icon variants with ImageMagick (800×800 + 1024×1024 for iOS):

| Theme | Background | Music note color | Output |
|-------|-----------|-----------------|--------|
| goldAmber | `#0A0A0A` | `#F59E0B` | `assets/images/icon_gold.png` |
| cyanTeal | `#030A0A` | `#06B6D4` | `assets/images/icon_teal.png` |
| coralOrange | `#0A0500` | `#F97316` | `assets/images/icon_coral.png` |
| oledWhite | `#000000` | `#FFFFFF` | `assets/images/icon_oled.png` |

Runtime icon switching:
- **iOS**: `flutter_dynamic_icon: ^0.3.0` — `FlutterDynamicIcon.setAlternateIconName('icon_gold')` on theme change. Requires `CFBundleAlternateIcons` entries in `Info.plist` and icon sets in `ios/Runner/Assets.xcassets/`.
- **Android**: Build-time only via `flutter_launcher_icons`. No runtime switching without the Shortcuts API; Android users get the default (goldAmber) icon regardless of theme.

---

## 3. Header / Logo Redesign

### Design: Tidal-inspired gradient header

Replaces plain `AppBar(title: Text('JUSPlay'))` in `home_screen.dart`.

**Visual anatomy:**
- Full-width `AppBar` with transparent background
- `flexibleSpace`: `Container` with a `LinearGradient` bleeding left-to-right from `accent.withOpacity(0.18)` to `Colors.transparent`
- Left: 40×40 glass icon container (music note SVG or `Icons.music_note`, accent fill at 12% opacity, border at 25% opacity) + "JUSPlay" `ShaderMask` wordmark (gradient from accent → accent at 60%)
- Right: Pill-shaped server status badge (green dot + server name, or red dot + "Offline")
- Bottom: 1px hairline via `AppBar.bottom` or `PreferredSize` — gradient from transparent → accent(50%) → transparent

**New widget:** `lib/features/home/widgets/jusplay_app_bar.dart` — a `PreferredSizeWidget` that takes `accentColor` and `serverName` parameters.

### Files changed
- `lib/features/home/widgets/jusplay_app_bar.dart` — new widget
- `lib/features/home/screens/home_screen.dart` — replace `AppBar` with `JUSPlayAppBar`

---

## 4. Lock Screen Audio Controls

### Verification task only

`audio_service` declares `UIBackgroundModes: audio` in its own `Info.plist` fragment — Flutter merges these at build time. Verify it's present in the compiled plist:

```bash
cat ios/Runner/Info.plist | grep -A3 UIBackgroundModes
```

If missing, add manually to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

**Dynamic Island:** Deferred. Requires a native Swift ActivityKit `Live Activity` extension — not achievable in Flutter without a separate native module. Parking this for a future milestone.

### Files possibly changed
- `ios/Runner/Info.plist` — only if `UIBackgroundModes` is absent

---

## 5. AI Smart Playlists

### New dependency
```yaml
# pubspec.yaml
google_generative_ai: ^0.4.6
```

### New files

**`lib/core/ai/playlist_generator.dart`**
Service class. Responsibilities:
- Build library summary string from `SubsonicApi.getSongs()` (id|title|artist|genre|duration)
- Detect iOS 18.1+ and call Foundation Models method channel; fall back to Gemini
- Parse JSON array response `["id1","id2",...]`
- Return `List<Song>` resolved against the full library

Gemini prompt template:
```
You are a music curator. Given the user's library below, select up to 25 song IDs
that best match the request. Return ONLY a valid JSON array of song ID strings.

Library genres: {genres}
Artists: {artists}
Songs (id|title|artist|genre|duration_secs):
{songList}

User request: "{userPrompt}"

Response format: ["id1","id2","id3"]
```

**`lib/features/playlists/screens/smart_playlist_screen.dart`**
- `TextField` for natural language prompt
- Chip row: Workout 💪, Focus 🎯, Chill 😌, Party 🎉, Sad hours 🌧, Road trip 🚗, Sleep 🌙, Morning coffee ☕
- Tapping a chip fills the text field
- Submit → loading shimmer → `ListView` of resolved songs → Play All button
- Privacy badge: 🔒 On-device (Foundation Models) or ☁️ Gemini

**`lib/features/home/widgets/smart_playlists_row.dart`**
- Horizontal scroll row of pre-generated smart playlist cards
- 8 preset prompts rendered as pill cards with emoji + label
- Tapping opens `smart_playlist_screen` with that prompt pre-filled
- Positioned as the **first** section in `HomeScreen` above the album carousels

### iOS Foundation Models stub

**`ios/Runner/AiMethodChannel.swift`** (new file, registered in `AppDelegate.swift`):
```swift
import Flutter
import Foundation

@available(iOS 18.1, *)
class AiMethodChannel {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.bliksemstudios.jusplay/ai",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            // Return nil — Gemini handles all requests for now
            result(FlutterMethodNotImplemented)
        }
    }
}
```

Flutter side checks `result == null` and falls through to Gemini. No actual model calls until the native side is implemented.

### Files changed
- `pubspec.yaml` — add `google_generative_ai`
- `lib/core/ai/playlist_generator.dart` — new
- `lib/features/playlists/screens/smart_playlist_screen.dart` — new
- `lib/features/home/widgets/smart_playlists_row.dart` — new
- `lib/features/home/screens/home_screen.dart` — add `SmartPlaylistsRow` as first section
- `ios/Runner/AiMethodChannel.swift` — new stub
- `ios/Runner/AppDelegate.swift` — register channel

---

## 6. Settings Screen Updates

### Appearance section — add theme picker

Below the existing Theme Mode list tile, add a new `AccentThemePicker` widget:
- 4 circular color swatches (40×40) in a horizontal row
- Selected swatch has a white ring border
- Tapping calls `ref.read(accentThemeProvider.notifier).setTheme(key)`
- Labels below each swatch

### New AI Features section (above About)

```
AI Features
├── [TextField] Gemini API Key  (obscured, stored in SettingsStorage as 'gemini_api_key')
└── [info text] Used to generate smart playlists when on-device AI is unavailable
```

### Files changed
- `lib/core/storage/settings_storage.dart` — add `geminiApiKey` / `setGeminiApiKey`
- `lib/features/settings/screens/settings_screen.dart` — add `AccentThemePicker` + AI Features section

---

## File Change Summary

| File | Change |
|------|--------|
| `lib/app.dart` | Stack overlay, `_ConditionalMiniPlayer`, theme wiring |
| `lib/core/router.dart` | `NavigatorObserver` → `currentRouteProvider`, remove MiniPlayer from shell |
| `lib/core/theme/app_theme.dart` | Replace purple with `forAccent(key)` factory |
| `lib/core/storage/settings_storage.dart` | `accentTheme`, `geminiApiKey` keys |
| `lib/core/providers/api_provider.dart` | `AccentThemeNotifier` + `accentThemeProvider` |
| `lib/features/home/screens/home_screen.dart` | New app bar + SmartPlaylistsRow first section |
| `lib/features/home/widgets/jusplay_app_bar.dart` | New — gradient header widget |
| `lib/features/home/widgets/smart_playlists_row.dart` | New — AI playlist home row |
| `lib/core/ai/playlist_generator.dart` | New — Gemini + method channel orchestrator |
| `lib/features/playlists/screens/smart_playlist_screen.dart` | New — full smart playlist UI |
| `lib/features/settings/screens/settings_screen.dart` | Theme swatch picker + AI section |
| `ios/Runner/Info.plist` | Add UIBackgroundModes if absent |
| `ios/Runner/AiMethodChannel.swift` | New — Foundation Models stub |
| `ios/Runner/AppDelegate.swift` | Register AI channel |
| `pubspec.yaml` | Add `google_generative_ai`, `flutter_dynamic_icon` |
| `assets/images/icon_*.png` | 4 themed icon variants |

---

## Out of Scope

- Dynamic Island (requires native ActivityKit Live Activity extension)
- Android runtime icon switching (platform limitation)
- Fastlane / store deployment
- Foundation Models actual implementation (stub only for now)
