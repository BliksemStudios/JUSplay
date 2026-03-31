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

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

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
        self.interfaceController = nil
        self.carplayChannel = nil
    }

    // MARK: - Root Template

    private func buildRootTemplate() {
        let tabs: [CPTemplate] = [
            buildRecentlyPlayedTab(),
            buildArtistsTab(),
            buildAlbumsTab(),
            buildPlaylistsTab(),
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

        fetchAlbums(type: "recent", limit: 20) { [weak self] items in
            template.updateSections([CPListSection(items: items)])
            template.emptyViewTitleVariants = ["No recent albums"]
        }

        return template
    }

    private func buildArtistsTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Artists", sections: [])
        template.tabImage = UIImage(systemName: "music.mic")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchArtists { [weak self] items in
            template.updateSections([CPListSection(items: items)])
            template.emptyViewTitleVariants = ["No artists"]
        }

        return template
    }

    private func buildAlbumsTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Albums", sections: [])
        template.tabImage = UIImage(systemName: "square.stack")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchAlbums(type: "alphabeticalByName", limit: 50) { [weak self] items in
            template.updateSections([CPListSection(items: items)])
            template.emptyViewTitleVariants = ["No albums"]
        }

        return template
    }

    private func buildPlaylistsTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Playlists", sections: [])
        template.tabImage = UIImage(systemName: "list.bullet")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchPlaylists { [weak self] items in
            template.updateSections([CPListSection(items: items)])
            template.emptyViewTitleVariants = ["No playlists"]
        }

        return template
    }

    private func buildFavouritesTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Favourites", sections: [])
        template.tabImage = UIImage(systemName: "heart.fill")
        template.emptyViewTitleVariants = ["Loading..."]

        fetchFavourites { [weak self] items in
            template.updateSections([CPListSection(items: items)])
            template.emptyViewTitleVariants = ["No favourites"]
        }

        return template
    }

    // MARK: - Data Fetching via Method Channel

    private func fetchArtists(completion: @escaping ([CPListItem]) -> Void) {
        carplayChannel?.invokeMethod("getArtists", arguments: nil) { [weak self] result in
            guard let artists = result as? [[String: Any]] else {
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

    private func fetchAlbums(type: String, limit: Int, completion: @escaping ([CPListItem]) -> Void) {
        let args: [String: Any] = ["type": type, "limit": limit]
        carplayChannel?.invokeMethod("getAlbums", arguments: args) { [weak self] result in
            guard let albums = result as? [[String: Any]] else {
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

    private func fetchPlaylists(completion: @escaping ([CPListItem]) -> Void) {
        carplayChannel?.invokeMethod("getPlaylists", arguments: nil) { [weak self] result in
            guard let playlists = result as? [[String: Any]] else {
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

    private func fetchFavourites(completion: @escaping ([CPListItem]) -> Void) {
        carplayChannel?.invokeMethod("getFavourites", arguments: nil) { [weak self] result in
            guard let songs = result as? [[String: Any]] else {
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

        carplayChannel?.invokeMethod("getArtistAlbums", arguments: ["id": artistId]) { [weak self] result in
            guard let albums = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["No albums"]
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
            template.emptyViewTitleVariants = ["No albums"]
        }

        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func showAlbumSongs(albumId: String, albumName: String) {
        let template = CPListTemplate(title: albumName, sections: [])
        template.emptyViewTitleVariants = ["Loading..."]

        carplayChannel?.invokeMethod("getAlbumSongs", arguments: ["id": albumId]) { [weak self] result in
            guard let songs = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["No songs"]
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
                template.emptyViewTitleVariants = ["No songs"]
            }
        }

        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func showPlaylistSongs(playlistId: String, playlistName: String) {
        let template = CPListTemplate(title: playlistName, sections: [])
        template.emptyViewTitleVariants = ["Loading..."]

        carplayChannel?.invokeMethod("getPlaylistSongs", arguments: ["id": playlistId]) { [weak self] result in
            guard let songs = result as? [[String: Any]] else {
                template.emptyViewTitleVariants = ["No songs"]
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
                template.emptyViewTitleVariants = ["No songs"]
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
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
}
