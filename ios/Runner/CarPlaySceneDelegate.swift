import CarPlay
import Flutter
import UIKit

/// Handles the CarPlay lifecycle and builds the browsable media interface.
///
/// The delegate receives connect/disconnect events from CarPlay and constructs
/// a tab-based UI with browsable categories (Artists, Albums, Playlists, etc.).
/// Data is fetched from the Subsonic server via a Flutter method channel.
@available(iOS 14.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private var carplayChannel: FlutterMethodChannel?

    /// Track pending fetches so we can retry on reconnect
    private var isConnected = false

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        self.isConnected = true

        // Get the binary messenger from the main app's Flutter engine
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let messenger = appDelegate.binaryMessenger {
            carplayChannel = FlutterMethodChannel(
                name: "com.bliksemstudios.jusplay/carplay",
                binaryMessenger: messenger
            )
        }

        buildRootTemplate()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.isConnected = false
        self.interfaceController = nil
        self.carplayChannel = nil
    }

    // MARK: - Root Template

    private func buildRootTemplate() {
        let tabs: [CPTemplate] = [
            buildRecentlyPlayedTab(),
            buildArtistsTab(),
            buildPlaylistsTab(),
            buildSongsTab(),
            buildFavouritesTab(),
        ]

        let tabBar = CPTabBarTemplate(templates: tabs)
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    // MARK: - Tab Builders

    private func buildRecentlyPlayedTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Recent", sections: [])
        template.tabImage = UIImage(systemName: "clock")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchAlbums(type: "recent", limit: 20, template: template) { [weak self] items in
            guard self?.isConnected == true else { return }
            template.updateSections([CPListSection(items: items)])
            if items.isEmpty {
                template.emptyViewTitleVariants = ["No recent albums"]
            }
        }

        return template
    }

    private func buildArtistsTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Artists", sections: [])
        template.tabImage = UIImage(systemName: "music.mic")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchArtists(template: template) { [weak self] items in
            guard self?.isConnected == true else { return }
            template.updateSections([CPListSection(items: items)])
            if items.isEmpty {
                template.emptyViewTitleVariants = ["No artists"]
            }
        }

        return template
    }

    private func buildPlaylistsTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Playlists", sections: [])
        template.tabImage = UIImage(systemName: "list.bullet")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchPlaylists(template: template) { [weak self] items in
            guard self?.isConnected == true else { return }
            template.updateSections([CPListSection(items: items)])
            if items.isEmpty {
                template.emptyViewTitleVariants = ["No playlists"]
            }
        }

        return template
    }

    private func buildSongsTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Songs", sections: [])
        template.tabImage = UIImage(systemName: "music.note")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchSongs(template: template) { [weak self] items in
            guard self?.isConnected == true else { return }
            // Add shuffle all at the top
            let shuffleAll = CPListItem(text: "Shuffle All", detailText: "\(items.count) songs")
            shuffleAll.setImage(UIImage(systemName: "shuffle"))
            shuffleAll.handler = { [weak self] _, completionHandler in
                self?.carplayChannel?.invokeMethod("playSongs", arguments: [
                    "source": "songs",
                    "sourceId": "all",
                    "startIndex": 0,
                    "shuffle": true,
                ])
                completionHandler()
            }

            let controlSection = CPListSection(items: [shuffleAll])
            let songsSection = CPListSection(items: items, header: "All Songs", sectionIndexTitle: nil)
            template.updateSections([controlSection, songsSection])
            if items.isEmpty {
                template.emptyViewTitleVariants = ["No songs"]
            }
        }

        return template
    }

    private func buildFavouritesTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Favourites", sections: [])
        template.tabImage = UIImage(systemName: "heart.fill")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchFavourites(template: template) { [weak self] items in
            guard self?.isConnected == true else { return }
            // Add shuffle favourites at top if we have songs
            if !items.isEmpty {
                let shuffleFavs = CPListItem(text: "Shuffle Favourites", detailText: "\(items.count) songs")
                shuffleFavs.setImage(UIImage(systemName: "shuffle"))
                shuffleFavs.handler = { [weak self] _, completionHandler in
                    self?.carplayChannel?.invokeMethod("playSongs", arguments: [
                        "source": "favourites",
                        "sourceId": "",
                        "startIndex": 0,
                        "shuffle": true,
                    ])
                    completionHandler()
                }
                let controlSection = CPListSection(items: [shuffleFavs])
                let songsSection = CPListSection(items: items, header: "Songs", sectionIndexTitle: nil)
                template.updateSections([controlSection, songsSection])
            } else {
                template.emptyViewTitleVariants = ["No favourites"]
            }
        }

        return template
    }

    // MARK: - Data Fetching via Method Channel (with retry)

    /// Wraps a method channel call with error handling and automatic retry.
    private func invokeWithRetry(
        _ method: String,
        arguments: Any? = nil,
        retryCount: Int = 2,
        retryDelay: TimeInterval = 2.0,
        completion: @escaping (Any?) -> Void
    ) {
        guard let channel = carplayChannel else {
            print("[CarPlay] No channel available for \(method)")
            if retryCount > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.invokeWithRetry(method, arguments: arguments,
                                         retryCount: retryCount - 1,
                                         retryDelay: retryDelay,
                                         completion: completion)
                }
            } else {
                completion(nil)
            }
            return
        }

        channel.invokeMethod(method, arguments: arguments) { [weak self] result in
            if let error = result as? FlutterError {
                print("[CarPlay] Error from \(method): \(error.code) - \(error.message ?? "")")
                if retryCount > 0 {
                    print("[CarPlay] Retrying \(method) in \(retryDelay)s (\(retryCount) left)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                        self?.invokeWithRetry(method, arguments: arguments,
                                             retryCount: retryCount - 1,
                                             retryDelay: retryDelay,
                                             completion: completion)
                    }
                } else {
                    completion(nil)
                }
                return
            }

            completion(result)
        }
    }

    private func fetchArtists(template: CPListTemplate, completion: @escaping ([CPListItem]) -> Void) {
        invokeWithRetry("getArtists") { [weak self] result in
            guard let artists = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["Could not load artists — tap to retry"]
                completion([])
                return
            }

            let items = artists.prefix(100).map { artist -> CPListItem in
                let name = artist["name"] as? String ?? "Unknown"
                let albumCount = artist["albumCount"] as? Int ?? 0
                let id = artist["id"] as? String ?? ""
                let coverArtUrl = artist["coverArtUrl"] as? String

                let item = CPListItem(
                    text: name,
                    detailText: "\(albumCount) album\(albumCount == 1 ? "" : "s")"
                )
                item.handler = { [weak self] _, completionHandler in
                    self?.showArtistAlbums(artistId: id, artistName: name)
                    completionHandler()
                }

                if let urlStr = coverArtUrl, let url = URL(string: urlStr) {
                    self?.loadImage(from: url) { image in
                        item.setImage(image)
                    }
                }

                return item
            }

            completion(Array(items))
        }
    }

    private func fetchAlbums(type: String, limit: Int, template: CPListTemplate, completion: @escaping ([CPListItem]) -> Void) {
        let args: [String: Any] = ["type": type, "limit": limit]
        invokeWithRetry("getAlbums", arguments: args) { [weak self] result in
            guard let albums = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["Could not load albums — tap to retry"]
                completion([])
                return
            }

            let items = albums.map { album -> CPListItem in
                let name = album["name"] as? String ?? "Unknown"
                let artist = album["artist"] as? String ?? ""
                let id = album["id"] as? String ?? ""
                let coverArtUrl = album["coverArtUrl"] as? String

                let item = CPListItem(
                    text: name,
                    detailText: artist
                )
                item.handler = { [weak self] _, completionHandler in
                    self?.showAlbumSongs(albumId: id, albumName: name)
                    completionHandler()
                }

                if let urlStr = coverArtUrl, let url = URL(string: urlStr) {
                    self?.loadImage(from: url) { image in
                        item.setImage(image)
                    }
                }

                return item
            }

            completion(items)
        }
    }

    private func fetchPlaylists(template: CPListTemplate, completion: @escaping ([CPListItem]) -> Void) {
        invokeWithRetry("getPlaylists") { [weak self] result in
            guard let playlists = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["Could not load playlists — tap to retry"]
                completion([])
                return
            }

            let items = playlists.map { playlist -> CPListItem in
                let name = playlist["name"] as? String ?? "Unknown"
                let songCount = playlist["songCount"] as? Int ?? 0
                let id = playlist["id"] as? String ?? ""
                let coverArtUrl = playlist["coverArtUrl"] as? String

                let item = CPListItem(
                    text: name,
                    detailText: "\(songCount) song\(songCount == 1 ? "" : "s")"
                )
                item.handler = { [weak self] _, completionHandler in
                    self?.showPlaylistSongs(playlistId: id, playlistName: name)
                    completionHandler()
                }

                if let urlStr = coverArtUrl, let url = URL(string: urlStr) {
                    self?.loadImage(from: url) { image in
                        item.setImage(image)
                    }
                }

                return item
            }

            completion(items)
        }
    }

    private func fetchSongs(template: CPListTemplate, completion: @escaping ([CPListItem]) -> Void) {
        invokeWithRetry("getSongs") { [weak self] result in
            guard let songs = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["Could not load songs"]
                completion([])
                return
            }

            self?.buildSongItems(from: songs, startIndex: 0, source: "songs", sourceId: "all") { items in
                completion(items)
            }
        }
    }

    private func fetchFavourites(template: CPListTemplate, completion: @escaping ([CPListItem]) -> Void) {
        invokeWithRetry("getFavourites") { [weak self] result in
            guard let songs = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["Could not load favourites"]
                completion([])
                return
            }

            self?.buildSongItems(from: songs, startIndex: 0, source: "favourites", sourceId: "") { items in
                completion(items)
            }
        }
    }

    // MARK: - Drill-down Screens

    private func showArtistAlbums(artistId: String, artistName: String) {
        let template = CPListTemplate(title: artistName, sections: [])
        template.emptyViewTitleVariants = ["Loading..."]

        invokeWithRetry("getArtistAlbums", arguments: ["id": artistId]) { [weak self] result in
            guard let albums = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["Could not load albums"]
                return
            }

            let items = albums.map { album -> CPListItem in
                let name = album["name"] as? String ?? "Unknown"
                let year = album["year"] as? Int
                let id = album["id"] as? String ?? ""
                let coverArtUrl = album["coverArtUrl"] as? String

                let detail = year != nil ? "\(year!)" : ""
                let item = CPListItem(text: name, detailText: detail)
                item.handler = { [weak self] _, completionHandler in
                    self?.showAlbumSongs(albumId: id, albumName: name)
                    completionHandler()
                }

                if let urlStr = coverArtUrl, let url = URL(string: urlStr) {
                    self?.loadImage(from: url) { image in
                        item.setImage(image)
                    }
                }

                return item
            }

            template.updateSections([CPListSection(items: items)])
            if items.isEmpty {
                template.emptyViewTitleVariants = ["No albums"]
            }
        }

        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func showAlbumSongs(albumId: String, albumName: String) {
        let template = CPListTemplate(title: albumName, sections: [])
        template.emptyViewTitleVariants = ["Loading..."]

        invokeWithRetry("getAlbumSongs", arguments: ["id": albumId]) { [weak self] result in
            guard let songs = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["Could not load songs"]
                return
            }

            self?.buildSongItems(from: songs, startIndex: 0, source: "album", sourceId: albumId) { items in
                // Add "Play All" and "Shuffle" at the top
                let playAll = CPListItem(text: "Play All", detailText: "\(songs.count) songs")
                playAll.setImage(UIImage(systemName: "play.fill"))
                playAll.handler = { [weak self] _, completionHandler in
                    self?.carplayChannel?.invokeMethod("playSongs", arguments: [
                        "source": "album",
                        "sourceId": albumId,
                        "startIndex": 0,
                        "shuffle": false,
                    ])
                    completionHandler()
                }

                let shuffle = CPListItem(text: "Shuffle", detailText: "\(songs.count) songs")
                shuffle.setImage(UIImage(systemName: "shuffle"))
                shuffle.handler = { [weak self] _, completionHandler in
                    self?.carplayChannel?.invokeMethod("playSongs", arguments: [
                        "source": "album",
                        "sourceId": albumId,
                        "startIndex": 0,
                        "shuffle": true,
                    ])
                    completionHandler()
                }

                let controlSection = CPListSection(items: [playAll, shuffle])
                let songsSection = CPListSection(items: items, header: "Songs", sectionIndexTitle: nil)
                template.updateSections([controlSection, songsSection])
                if items.isEmpty {
                    template.emptyViewTitleVariants = ["No songs"]
                }
            }
        }

        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func showPlaylistSongs(playlistId: String, playlistName: String) {
        let template = CPListTemplate(title: playlistName, sections: [])
        template.emptyViewTitleVariants = ["Loading..."]

        invokeWithRetry("getPlaylistSongs", arguments: ["id": playlistId]) { [weak self] result in
            guard let songs = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["Could not load songs"]
                return
            }

            self?.buildSongItems(from: songs, startIndex: 0, source: "playlist", sourceId: playlistId) { items in
                let playAll = CPListItem(text: "Play All", detailText: "\(songs.count) songs")
                playAll.setImage(UIImage(systemName: "play.fill"))
                playAll.handler = { [weak self] _, completionHandler in
                    self?.carplayChannel?.invokeMethod("playSongs", arguments: [
                        "source": "playlist",
                        "sourceId": playlistId,
                        "startIndex": 0,
                        "shuffle": false,
                    ])
                    completionHandler()
                }

                let shuffle = CPListItem(text: "Shuffle", detailText: "\(songs.count) songs")
                shuffle.setImage(UIImage(systemName: "shuffle"))
                shuffle.handler = { [weak self] _, completionHandler in
                    self?.carplayChannel?.invokeMethod("playSongs", arguments: [
                        "source": "playlist",
                        "sourceId": playlistId,
                        "startIndex": 0,
                        "shuffle": true,
                    ])
                    completionHandler()
                }

                let controlSection = CPListSection(items: [playAll, shuffle])
                let songsSection = CPListSection(items: items, header: "Songs", sectionIndexTitle: nil)
                template.updateSections([controlSection, songsSection])
                if items.isEmpty {
                    template.emptyViewTitleVariants = ["No songs"]
                }
            }
        }

        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - Song Item Builder

    private func buildSongItems(
        from songs: [[String: Any]],
        startIndex: Int,
        source: String,
        sourceId: String,
        completion: @escaping ([CPListItem]) -> Void
    ) {
        let items = songs.enumerated().map { (index, song) -> CPListItem in
            let title = song["title"] as? String ?? "Unknown"
            let artist = song["artist"] as? String ?? ""
            let coverArtUrl = song["coverArtUrl"] as? String

            let item = CPListItem(text: title, detailText: artist)
            item.handler = { [weak self] _, completionHandler in
                self?.carplayChannel?.invokeMethod("playSongs", arguments: [
                    "source": source,
                    "sourceId": sourceId,
                    "startIndex": index,
                    "shuffle": false,
                ])
                completionHandler()
            }

            if let urlStr = coverArtUrl, let url = URL(string: urlStr) {
                self.loadImage(from: url) { image in
                    item.setImage(image)
                }
            }

            return item
        }

        completion(items)
    }

    // MARK: - Image Loading

    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[CarPlay] Image load failed: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                if let data = data, let image = UIImage(data: data) {
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
}
