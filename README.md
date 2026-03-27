# JUSPlay

**Just yoUr Subsonic Player** — A free, open-source, cross-platform music streaming app that connects to any Subsonic-compatible server.

Works with [Navidrome](https://www.navidrome.org/), [Airsonic](https://airsonic.github.io/), [Gonic](https://github.com/sentriz/gonic), [Ampache](https://ampache.org/), and any other Subsonic API-compatible server.

## Features

- Stream music from your Subsonic-compatible server
- Browse by artists, albums, genres, playlists
- Search your entire library
- Background playback with lock screen controls
- Queue management with shuffle and repeat
- Offline downloads and smart caching
- Star/favorite songs, albums, and artists
- Scrobbling support (Last.fm, ListenBrainz via server)
- CarPlay and Android Auto support
- Dark and light themes
- Configurable streaming quality

## Platforms

| Platform | Status |
|----------|--------|
| iOS (iPhone) | Primary |
| Android | Primary |
| CarPlay | Planned |
| Android Auto | Planned |
| Apple Watch | Planned |
| Wear OS | Planned |

## Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Riverpod
- **Audio**: just_audio + audio_service
- **Networking**: Dio
- **Local Storage**: Hive

## Getting Started

### Prerequisites

- Flutter SDK 3.11+
- A Subsonic-compatible music server

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

Made with music by [BliksemStudios](https://github.com/BliksemStudios)
