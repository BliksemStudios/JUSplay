import SwiftUI

struct BrowseView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: RecentAlbumsView()) {
                    Label("Recent Albums", systemImage: "clock")
                }

                NavigationLink(destination: PlaylistsView()) {
                    Label("Playlists", systemImage: "music.note.list")
                }

                NavigationLink(destination: FavouritesView()) {
                    Label("Favourites", systemImage: "heart.fill")
                }

                // Settings section
                Section("Settings") {
                    ModeSettingRow()

                    if let config = appState.connectivity.serverConfig {
                        HStack {
                            Text("Server")
                                .font(.caption2)
                            Spacer()
                            Text(config.name)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section {
                    VStack(spacing: 2) {
                        Text("Watch App v5.1 (build 6)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("Mode: \(appState.mode.rawValue)")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.7))
                        Text("iPhone: \(appState.connectivity.isReachable ? "reachable" : "not reachable")")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.7))
                        Text("Config: \(appState.connectivity.serverConfig != nil ? "yes" : "no")")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Browse")
        }
    }
}

// MARK: - Recent Albums

struct RecentAlbumsView: View {
    @EnvironmentObject var appState: AppState
    @State private var albums: [BrowseItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if albums.isEmpty {
                Text("No recent albums")
                    .foregroundColor(.gray)
            } else {
                List(albums) { album in
                    NavigationLink(destination: AlbumDetailView(
                        albumId: album.id,
                        albumName: album.name
                    )) {
                        HStack(spacing: 10) {
                            CoverArtView(url: album.coverArtUrl, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                if let artist = album.subtitle {
                                    Text(artist)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Recent")
        .task {
            albums = await appState.fetchRecentAlbums()
            isLoading = false
        }
    }
}

// MARK: - Playlists

struct PlaylistsView: View {
    @EnvironmentObject var appState: AppState
    @State private var playlists: [BrowseItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if playlists.isEmpty {
                Text("No playlists")
                    .foregroundColor(.gray)
            } else {
                List(playlists) { playlist in
                    NavigationLink(destination: PlaylistDetailView(
                        playlistId: playlist.id,
                        playlistName: playlist.name
                    )) {
                        HStack(spacing: 10) {
                            CoverArtView(url: playlist.coverArtUrl, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                if let count = playlist.songCount {
                                    Text("\(count) songs")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Playlists")
        .task {
            playlists = await appState.fetchPlaylists()
            isLoading = false
        }
    }
}

// MARK: - Favourites

struct FavouritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var songs: [SongItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if songs.isEmpty {
                Text("No favourites")
                    .foregroundColor(.gray)
            } else {
                SongListView(
                    songs: songs,
                    source: "favourites",
                    sourceId: ""
                )
            }
        }
        .navigationTitle("Favourites")
        .task {
            songs = await appState.fetchFavourites()
            isLoading = false
        }
    }
}

// MARK: - Album Detail

struct AlbumDetailView: View {
    @EnvironmentObject var appState: AppState
    let albumId: String
    let albumName: String
    @State private var songs: [SongItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if songs.isEmpty {
                Text("No songs")
                    .foregroundColor(.gray)
            } else {
                SongListView(
                    songs: songs,
                    source: "album",
                    sourceId: albumId
                )
            }
        }
        .navigationTitle(albumName)
        .task {
            songs = await appState.fetchAlbumSongs(albumId)
            isLoading = false
        }
    }
}

// MARK: - Playlist Detail

struct PlaylistDetailView: View {
    @EnvironmentObject var appState: AppState
    let playlistId: String
    let playlistName: String
    @State private var songs: [SongItem] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if songs.isEmpty {
                Text("No songs")
                    .foregroundColor(.gray)
            } else {
                SongListView(
                    songs: songs,
                    source: "playlist",
                    sourceId: playlistId
                )
            }
        }
        .navigationTitle(playlistName)
        .task {
            songs = await appState.fetchPlaylistSongs(playlistId)
            isLoading = false
        }
    }
}

// MARK: - Reusable Song List

struct SongListView: View {
    @EnvironmentObject var appState: AppState
    let songs: [SongItem]
    let source: String
    let sourceId: String

    var body: some View {
        List {
            // Shuffle all button
            Button(action: {
                appState.playSongs(
                    source: source,
                    sourceId: sourceId,
                    shuffle: true
                )
            }) {
                Label("Shuffle All", systemImage: "shuffle")
                    .foregroundColor(.orange)
            }

            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                Button(action: {
                    appState.playSongs(
                        source: source,
                        sourceId: sourceId,
                        startIndex: index
                    )
                }) {
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(song.title)
                                .font(.caption)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(song.formattedDuration)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Mode Setting Row

struct ModeSettingRow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button(action: {
            // Cycle through modes or show picker
            if appState.connectivity.serverConfig != nil {
                appState.showModePicker = true
            }
        }) {
            HStack {
                Image(systemName: appState.mode == .standalone
                      ? "applewatch" : "iphone")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Play Mode")
                        .font(.caption)
                    Text(appState.mode == .standalone
                         ? "Standalone" : "Remote")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cover Art Helper

struct CoverArtView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        if let urlString = url, let imageUrl = URL(string: urlString) {
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .cornerRadius(6)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "music.note")
                    .font(.caption2)
                    .foregroundColor(.gray)
            )
    }
}
