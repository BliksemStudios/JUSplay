import Foundation
import WatchConnectivity

/// Manages WatchConnectivity on the Watch side.
/// Sends commands to iPhone and receives playback state + server config updates.
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchConnectivityManager()

    @Published var nowPlaying: NowPlayingState?
    @Published var isConnected = false
    @Published var isReachable = false
    @Published var serverConfig: ServerConfig?

    private var session: WCSession?

    private override init() {
        super.init()
        loadServerConfig()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Server Config Persistence

    private func loadServerConfig() {
        guard let data = UserDefaults.standard.data(forKey: "serverConfig"),
              let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return
        }
        serverConfig = config
    }

    private func saveServerConfig(_ config: ServerConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "serverConfig")
        }
        DispatchQueue.main.async {
            self.serverConfig = config
        }
    }

    // MARK: - Send Commands to iPhone

    /// Sends a method call to the iPhone app and returns the reply.
    func sendCommand(_ method: String, arguments: [String: Any]? = nil) async throws -> [String: Any] {
        guard let session = session, session.isReachable else {
            throw WatchError.notReachable
        }

        return try await withCheckedThrowingContinuation { continuation in
            var message: [String: Any] = ["method": method]
            if let arguments = arguments {
                message["arguments"] = arguments
            }

            session.sendMessage(message, replyHandler: { reply in
                continuation.resume(returning: reply)
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    /// Fire-and-forget command (no reply needed).
    func sendCommandNoReply(_ method: String, arguments: [String: Any]? = nil) {
        guard let session = session, session.isReachable else { return }

        var message: [String: Any] = ["method": method]
        if let arguments = arguments {
            message["arguments"] = arguments
        }
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("[Watch] sendCommand error: \(error)")
        })
    }

    // MARK: - Convenience Methods (Remote Control)

    func playPause() {
        sendCommandNoReply("playPause")
    }

    func skipNext() {
        sendCommandNoReply("skipNext")
    }

    func skipPrev() {
        sendCommandNoReply("skipPrev")
    }

    func seekTo(_ position: Double) {
        sendCommandNoReply("seekTo", arguments: ["position": position])
    }

    func playSongs(source: String, sourceId: String, startIndex: Int = 0, shuffle: Bool = false) {
        sendCommandNoReply("playSongs", arguments: [
            "source": source,
            "sourceId": sourceId,
            "startIndex": startIndex,
            "shuffle": shuffle,
        ])
    }

    func fetchNowPlaying() async -> NowPlayingState? {
        do {
            let reply = try await sendCommand("getNowPlaying")
            return NowPlayingState.from(reply)
        } catch {
            return nil
        }
    }

    func fetchRecentAlbums() async -> [BrowseItem] {
        do {
            let reply = try await sendCommand("getRecentAlbums")
            return BrowseItem.fromList(reply["items"] as? [[String: Any]] ?? [])
        } catch {
            return []
        }
    }

    func fetchPlaylists() async -> [BrowseItem] {
        do {
            let reply = try await sendCommand("getPlaylists")
            return BrowseItem.fromList(reply["items"] as? [[String: Any]] ?? [])
        } catch {
            return []
        }
    }

    func fetchAlbumSongs(_ albumId: String) async -> [SongItem] {
        do {
            let reply = try await sendCommand("getAlbumSongs", arguments: ["id": albumId])
            return SongItem.fromList(reply["items"] as? [[String: Any]] ?? [])
        } catch {
            return []
        }
    }

    func fetchPlaylistSongs(_ playlistId: String) async -> [SongItem] {
        do {
            let reply = try await sendCommand("getPlaylistSongs", arguments: ["id": playlistId])
            return SongItem.fromList(reply["items"] as? [[String: Any]] ?? [])
        } catch {
            return []
        }
    }

    func fetchFavourites() async -> [SongItem] {
        do {
            let reply = try await sendCommand("getFavourites")
            return SongItem.fromList(reply["items"] as? [[String: Any]] ?? [])
        } catch {
            return []
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    /// Receives real-time messages from iPhone.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    /// Receives queued user info transfers (reliable delivery for server config).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncomingMessage(userInfo)
    }

    /// Receives application context updates (persisted, received on wake).
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        // Check for nested server config
        if let configDict = applicationContext["serverConfig"] as? [String: Any] {
            if let config = ServerConfig.from(configDict) {
                saveServerConfig(config)
            }
        }
        // Check for playback state
        if applicationContext["type"] as? String == "playbackState" {
            DispatchQueue.main.async {
                if applicationContext["stopped"] as? Bool == true {
                    self.nowPlaying = nil
                } else {
                    self.nowPlaying = NowPlayingState.from(applicationContext)
                }
            }
        }
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        let type = message["type"] as? String

        if type == "serverConfig" {
            if let config = ServerConfig.from(message) {
                saveServerConfig(config)
            }
        } else if type == "playbackState" {
            DispatchQueue.main.async {
                if message["stopped"] as? Bool == true {
                    self.nowPlaying = nil
                } else {
                    self.nowPlaying = NowPlayingState.from(message)
                }
            }
        }
    }
}

// MARK: - Models

enum WatchError: Error {
    case notReachable
    case invalidResponse
    case noServerConfig
}

struct ServerConfig: Codable {
    let url: String
    let username: String
    let password: String
    let token: String
    let salt: String
    let name: String

    var authParams: [String: String] {
        ["u": username, "t": token, "s": salt, "v": "1.16.1", "c": "jusplay", "f": "json"]
    }

    static func from(_ dict: [String: Any]) -> ServerConfig? {
        guard let url = dict["url"] as? String,
              let username = dict["username"] as? String,
              let password = dict["password"] as? String,
              let token = dict["token"] as? String,
              let salt = dict["salt"] as? String else { return nil }
        return ServerConfig(
            url: url,
            username: username,
            password: password,
            token: token,
            salt: salt,
            name: dict["name"] as? String ?? "Server"
        )
    }
}

struct NowPlayingState {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let position: Double
    let isPlaying: Bool
    let coverArtUrl: String?

    static func from(_ dict: [String: Any]) -> NowPlayingState? {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String else { return nil }

        return NowPlayingState(
            id: id,
            title: title,
            artist: dict["artist"] as? String ?? "",
            album: dict["album"] as? String ?? "",
            duration: dict["duration"] as? Double ?? 0,
            position: dict["position"] as? Double ?? 0,
            isPlaying: dict["isPlaying"] as? Bool ?? false,
            coverArtUrl: dict["coverArtUrl"] as? String
        )
    }
}

struct BrowseItem: Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let coverArtUrl: String?
    let songCount: Int?

    static func fromList(_ list: [[String: Any]]) -> [BrowseItem] {
        list.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String else { return nil }
            return BrowseItem(
                id: id,
                name: name,
                subtitle: dict["artist"] as? String,
                coverArtUrl: dict["coverArtUrl"] as? String,
                songCount: dict["songCount"] as? Int
            )
        }
    }
}

struct SongItem: Identifiable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Int
    let coverArtUrl: String?

    static func fromList(_ list: [[String: Any]]) -> [SongItem] {
        list.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String else { return nil }
            return SongItem(
                id: id,
                title: title,
                artist: dict["artist"] as? String ?? "",
                album: dict["album"] as? String ?? "",
                duration: dict["duration"] as? Int ?? 0,
                coverArtUrl: dict["coverArtUrl"] as? String
            )
        }
    }

    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
