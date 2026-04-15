import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var appState: AppState
    @State private var localPosition: Double = 0
    @State private var isDragging = false

    private var np: NowPlayingState? {
        appState.nowPlaying
    }

    var body: some View {
        if let np = np {
            ScrollView {
                VStack(spacing: 8) {
                    // Mode indicator
                    HStack {
                        Spacer()
                        Image(systemName: appState.mode == .standalone
                              ? "applewatch" : "iphone")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    // Album art
                    if let urlString = np.coverArtUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(12)
                            case .failure:
                                albumPlaceholder
                            default:
                                albumPlaceholder
                            }
                        }
                    } else {
                        albumPlaceholder
                    }

                    // Title & Artist
                    VStack(spacing: 2) {
                        Text(np.title)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundColor(.white)

                        Text(np.artist)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.gray)
                    }

                    // Progress bar
                    if np.duration > 0 {
                        VStack(spacing: 2) {
                            Slider(
                                value: Binding(
                                    get: { isDragging ? localPosition : currentPosition },
                                    set: { newValue in
                                        localPosition = newValue
                                        isDragging = true
                                    }
                                ),
                                in: 0...max(np.duration, 1),
                                onEditingChanged: { editing in
                                    if !editing {
                                        appState.seekTo(localPosition)
                                        isDragging = false
                                    }
                                }
                            )
                            .tint(.orange)

                            HStack {
                                Text(formatTime(isDragging ? localPosition : currentPosition))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(formatTime(np.duration))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    // Controls
                    HStack(spacing: 20) {
                        Button(action: { appState.skipPrev() }) {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Button(action: { appState.playPause() }) {
                            Image(systemName: np.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        Button(action: { appState.skipNext() }) {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    // Volume
                    VolumeControl()
                        .frame(height: 20)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 8)
            }
            .navigationTitle("Now Playing")
        } else {
            VStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("Not Playing")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text(appState.mode == .standalone
                     ? "Browse to start playing"
                     : "Play something on your iPhone")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Now Playing")
            .task {
                if appState.mode == .remote {
                    if let np = await appState.connectivity.fetchNowPlaying() {
                        appState.connectivity.nowPlaying = np
                    }
                }
            }
        }
    }

    /// Current position — in standalone mode, use audioManager's live value.
    private var currentPosition: Double {
        if appState.mode == .standalone {
            return appState.audioManager.currentTime
        }
        return np?.position ?? 0
    }

    private var albumPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "music.note")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            )
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}

/// WKInterfaceDevice volume control using the system volume slider.
struct VolumeControl: WKInterfaceObjectRepresentable {
    typealias WKInterfaceObjectType = WKInterfaceVolumeControl

    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        let control = WKInterfaceVolumeControl(origin: .local)
        control.setTintColor(.orange)
        return control
    }

    func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceVolumeControl, context: Context) {}
}
