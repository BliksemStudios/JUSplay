import Foundation

/// Direct HTTP client for the Subsonic API, used on watchOS for standalone mode.
/// Mirrors the Dart SubsonicApi pattern using URLSession.
class SubsonicService {

    private let config: ServerConfig
    private let baseUrl: String
    private let session: URLSession

    init(config: ServerConfig) {
        self.config = config
        self.baseUrl = "\(config.url)/rest/"
        let urlConfig = URLSessionConfiguration.default
        urlConfig.timeoutIntervalForRequest = 15
        urlConfig.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: urlConfig)
    }

    // MARK: - URL Builders

    func streamUrl(_ id: String) -> String {
        buildUrl("stream.view", params: ["id": id])
    }

    func coverArtUrl(_ id: String?, size: Int = 200) -> String? {
        guard let id = id else { return nil }
        return buildUrl("getCoverArt.view", params: ["id": id, "size": "\(size)"])
    }

    // MARK: - API Methods

    func getAlbumList(type: String = "recent", size: Int = 25) async throws -> [BrowseItem] {
        let data = try await get("getAlbumList2.view", params: ["type": type, "size": "\(size)"])
        guard let albumList = data["albumList2"] as? [String: Any],
              let albums = albumList["album"] as? [[String: Any]] else { return [] }

        return albums.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String else { return nil }
            return BrowseItem(
                id: id,
                name: name,
                subtitle: dict["artist"] as? String,
                coverArtUrl: coverArtUrl(dict["coverArt"] as? String),
                songCount: dict["songCount"] as? Int
            )
        }
    }

    func getPlaylists() async throws -> [BrowseItem] {
        let data = try await get("getPlaylists.view")
        guard let playlists = data["playlists"] as? [String: Any],
              let list = playlists["playlist"] as? [[String: Any]] else { return [] }

        return list.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String else { return nil }
            return BrowseItem(
                id: id,
                name: name,
                subtitle: nil,
                coverArtUrl: coverArtUrl(dict["coverArt"] as? String),
                songCount: dict["songCount"] as? Int
            )
        }
    }

    func getPlaylistSongs(_ playlistId: String) async throws -> [SongItem] {
        let data = try await get("getPlaylist.view", params: ["id": playlistId])
        guard let playlist = data["playlist"] as? [String: Any],
              let entries = playlist["entry"] as? [[String: Any]] else { return [] }
        return parseSongs(entries)
    }

    func getAlbumSongs(_ albumId: String) async throws -> [SongItem] {
        let data = try await get("getAlbum.view", params: ["id": albumId])
        guard let album = data["album"] as? [String: Any],
              let songs = album["song"] as? [[String: Any]] else { return [] }
        return parseSongs(songs)
    }

    func getStarred() async throws -> [SongItem] {
        let data = try await get("getStarred2.view")
        guard let starred = data["starred2"] as? [String: Any],
              let songs = starred["song"] as? [[String: Any]] else { return [] }
        return parseSongs(songs)
    }

    // MARK: - Private

    private func buildUrl(_ endpoint: String, params: [String: String] = [:]) -> String {
        var components = URLComponents(string: "\(baseUrl)\(endpoint)")!
        var queryItems = config.authParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? ""
    }

    private func get(_ endpoint: String, params: [String: String] = [:]) async throws -> [String: Any] {
        let urlString = buildUrl(endpoint, params: params)
        guard let url = URL(string: urlString) else {
            throw WatchError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WatchError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subsonicResponse = json["subsonic-response"] as? [String: Any],
              subsonicResponse["status"] as? String == "ok" else {
            throw WatchError.invalidResponse
        }

        return subsonicResponse
    }

    private func parseSongs(_ list: [[String: Any]]) -> [SongItem] {
        list.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String else { return nil }
            return SongItem(
                id: id,
                title: title,
                artist: dict["artist"] as? String ?? "",
                album: dict["album"] as? String ?? "",
                duration: dict["duration"] as? Int ?? 0,
                coverArtUrl: coverArtUrl(dict["coverArt"] as? String)
            )
        }
    }
}
