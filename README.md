<p align="center">
  <img src="logo.png" width="128" height="128" alt="JUSPlay Logo">
</p>

<h1 align="center">JUSPlay</h1>

<p align="center">
  <strong>Just yoUr Subsonic Player</strong><br>
  A free, open-source, cross-platform music streaming app for any Subsonic-compatible server.
</p>

<p align="center">
  <a href="https://github.com/BliksemStudios/JUSplay/actions/workflows/ci.yml">
    <img src="https://github.com/BliksemStudios/JUSplay/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  <a href="https://github.com/BliksemStudios/JUSplay/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/BliksemStudios/JUSplay" alt="License">
  </a>
  <img src="https://img.shields.io/badge/flutter-3.41+-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/platforms-iOS%20%7C%20Android-brightgreen" alt="Platforms">
</p>

---

Works with [Navidrome](https://www.navidrome.org/), [Airsonic](https://airsonic.github.io/), [Gonic](https://github.com/sentriz/gonic), [Ampache](https://ampache.org/), and any other Subsonic API-compatible server.

## Features

### Playback
- Stream music from your Subsonic-compatible server
- Background playback with lock screen and notification controls
- Queue management with shuffle and repeat modes
- Gapless playback

### Library
- Browse by artists, albums, genres, and playlists
- Full-text search across your entire library
- Favourites with dedicated screen for starred songs
- Create, edit, and delete playlists

### AI-Powered Smart Playlists
- Describe what you want to listen to in natural language
- **Apple Intelligence** (iOS 26+) — on-device AI, fully private
- **Gemini** — cloud AI with multi-step generation for precise results
- **Smart Match** — algorithmic fallback that works without any API key
- Artist diversity enforcement across all AI modes
- Quick-start preset chips for common moods and vibes

### Design
- Material You theming with dynamic accent colours
- Dark and light modes
- Multiple app icon options (Gold, Coral, Cyan, OLED)
- Mini player with full-screen now-playing view

### Platform Integration
- Android Auto support
- CarPlay support (planned)
- Apple Watch (planned)
- Configurable streaming quality and caching

## Screenshots

> Coming soon

## Platforms

| Platform | Status |
|----------|--------|
| iOS (iPhone) | Active |
| Android | Active |
| Android Auto | Supported |
| CarPlay | Planned |
| Apple Watch | Planned |

## Tech Stack

- **Framework**: Flutter / Dart
- **State Management**: Riverpod
- **Audio**: just_audio + audio_service
- **Navigation**: go_router
- **Networking**: Dio + cached_network_image
- **AI**: Apple Foundation Models, Google Generative AI, algorithmic fallback
- **Local Storage**: Hive

## Getting Started

### Prerequisites

- Flutter SDK 3.41+
- A Subsonic-compatible music server (Navidrome, Airsonic, Gonic, etc.)

### Build & Run

```bash
flutter pub get
flutter run
```

### Connect to Your Server

1. Launch the app
2. Enter your server URL, username, and password
3. Start listening

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Support

If you enjoy JUSPlay, consider supporting development:
- Star this repo
- Report bugs and suggest features via [Issues](https://github.com/BliksemStudios/JUSplay/issues)

---

<p align="center">Made with music by <a href="https://github.com/BliksemStudios">BliksemStudios</a></p>
