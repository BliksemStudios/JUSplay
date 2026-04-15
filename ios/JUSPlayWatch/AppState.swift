import Foundation
import Combine
import WatchConnectivity

/// Central state manager that determines whether the Watch operates in
/// remote mode (relaying to iPhone) or standalone mode (direct server access).
class AppState: ObservableObject {

    enum Mode: String, Equatable {
        case unconfigured  // No server credentials — waiting for iPhone sync
        case remote        // iPhone is reachable — relay commands
        case standalone    // Direct server access — plays on Watch
    }

    @Published var mode: Mode = .unconfigured

    /// User's explicit preference. nil = not yet chosen (will prompt).
    @Published var userPreference: Mode? {
        didSet {
            if let pref = userPreference {
                UserDefaults.standard.set(pref.rawValue, forKey: "modePreference")
            } else {
                UserDefaults.standard.removeObject(forKey: "modePreference")
            }
        }
    }

    /// Whether to show the mode picker sheet
    @Published var showModePicker = false

    let connectivity = WatchConnectivityManager.shared
    let audioManager = AudioManager()

    private var subsonic: SubsonicService?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load saved preference
        if let raw = UserDefaults.standard.string(forKey: "modePreference"),
           let pref = Mode(rawValue: raw) {
            userPreference = pref
        }

        // Observe reachability and server config changes via Combine
        connectivity.$isReachable
            .combineLatest(connectivity.$serverConfig)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.evaluateMode()
            }
            .store(in: &cancellables)

        // Also re-evaluate when user sets preference
        $userPreference
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateMode()
            }
            .store(in: &cancellables)

        evaluateMode()
    }

    func evaluateMode() {
        let hasConfig = connectivity.serverConfig != nil
        let reachable = connectivity.isReachable

        // No server config at all → unconfigured
        guard hasConfig else {
            setMode(.unconfigured)
            return
        }

        // iPhone NOT reachable → standalone (no choice needed)
        if !reachable {
            setMode(.standalone)
            return
        }

        // iPhone IS reachable:
        // If user has a preference, respect it
        if let pref = userPreference {
            setMode(pref == .remote ? .remote : .standalone)
            return
        }

        // No preference yet → prompt user
        // Default to remote until they choose
        setMode(.remote)
        if !showModePicker {
            showModePicker = true
        }
    }

    /// Set the active mode, creating SubsonicService when entering standalone.
    private func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode

        if newMode == .standalone, let config = connectivity.serverConfig {
            subsonic = SubsonicService(config: config)
            print("[AppState] Entered standalone mode — SubsonicService created for \(config.url)")
        } else if newMode == .remote {
            // Stop local playback when switching to remote
            if audioManager.isPlaying {
                audioManager.stop()
            }
            subsonic = nil
            print("[AppState] Entered remote mode")
        } else if newMode == .unconfigured {
            subsonic = nil
            print("[AppState] Unconfigured — waiting for server config")
        }
    }

    /// Called from mode picker UI
    func selectMode(_ selected: Mode) {
        userPreference = selected
        showModePicker = false
    }

    /// Reset preference (e.g., from settings)
    func resetModePreference() {
        userPreference = nil
        evaluateMode()
    }

    // MARK: - Data Fetching (abstracts remote vs standalone)

    func fetchRecentAlbums() async -> [BrowseItem] {
        if mode == .remote {
            return await connectivity.fetchRecentAlbums()
        } else if let subsonic = subsonic {
            return (try? await subsonic.getAlbumList()) ?? []
        }
        return []
    }

    func fetchPlaylists() async -> [BrowseItem] {
        if mode == .remote {
            return await connectivity.fetchPlaylists()
        } else if let subsonic = subsonic {
            return (try? await subsonic.getPlaylists()) ?? []
        }
        return []
    }

    func fetchAlbumSongs(_ albumId: String) async -> [SongItem] {
        if mode == .remote {
            return await connectivity.fetchAlbumSongs(albumId)
        } else if let subsonic = subsonic {
            return (try? await subsonic.getAlbumSongs(albumId)) ?? []
        }
        return []
    }

    func fetchPlaylistSongs(_ playlistId: String) async -> [SongItem] {
        if mode == .remote {
            return await connectivity.fetchPlaylistSongs(playlistId)
        } else if let subsonic = subsonic {
            return (try? await subsonic.getPlaylistSongs(playlistId)) ?? []
        }
        return []
    }

    func fetchFavourites() async -> [SongItem] {
        if mode == .remote {
            return await connectivity.fetchFavourites()
        } else if let subsonic = subsonic {
            return (try? await subsonic.getStarred()) ?? []
        }
        return []
    }

    // MARK: - Playback (abstracts remote vs standalone)

    func playSongs(source: String, sourceId: String, startIndex: Int = 0, shuffle: Bool = false) {
        if mode == .remote {
            connectivity.playSongs(source: source, sourceId: sourceId,
                                   startIndex: startIndex, shuffle: shuffle)
        } else {
            // Standalone: need to fetch songs then play locally
            Task {
                var songs: [SongItem]
                switch source {
                case "album":
                    songs = await fetchAlbumSongs(sourceId)
                case "playlist":
                    songs = await fetchPlaylistSongs(sourceId)
                case "favourites":
                    songs = await fetchFavourites()
                default:
                    return
                }

                if songs.isEmpty { return }

                var idx = startIndex
                if shuffle {
                    songs.shuffle()
                    idx = 0
                }

                guard let subsonic = subsonic else { return }
                await MainActor.run {
                    audioManager.playQueue(
                        songs: songs,
                        startIndex: idx,
                        streamUrlProvider: { subsonic.streamUrl($0) }
                    )
                }
            }
        }
    }

    func playPause() {
        if mode == .remote {
            connectivity.playPause()
        } else {
            audioManager.togglePlayPause()
        }
    }

    func skipNext() {
        if mode == .remote {
            connectivity.skipNext()
        } else {
            audioManager.skipNext()
        }
    }

    func skipPrev() {
        if mode == .remote {
            connectivity.skipPrev()
        } else {
            audioManager.skipPrevious()
        }
    }

    func seekTo(_ position: Double) {
        if mode == .remote {
            connectivity.seekTo(position)
        } else {
            audioManager.seek(to: position)
        }
    }

    // MARK: - Now Playing State

    /// Returns current now playing state regardless of mode.
    var nowPlaying: NowPlayingState? {
        if mode == .remote {
            return connectivity.nowPlaying
        } else if let song = audioManager.currentSong {
            return NowPlayingState(
                id: song.id,
                title: song.title,
                artist: song.artist,
                album: song.album,
                duration: Double(song.duration),
                position: audioManager.currentTime,
                isPlaying: audioManager.isPlaying,
                coverArtUrl: song.coverArtUrl
            )
        }
        return nil
    }

    var isPlaying: Bool {
        if mode == .remote {
            return connectivity.nowPlaying?.isPlaying ?? false
        } else {
            return audioManager.isPlaying
        }
    }
}
