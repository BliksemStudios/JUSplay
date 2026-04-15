import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.mode == .unconfigured {
                UnconfiguredView()
            } else {
                TabView {
                    NowPlayingView()
                    BrowseView()
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .sheet(isPresented: $appState.showModePicker) {
            ModePickerView()
                .environmentObject(appState)
        }
    }
}

struct UnconfiguredView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Connect to iPhone")
                .font(.headline)

            Text("Open JUSPlay on your iPhone to sync server settings")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if appState.connectivity.isReachable {
                Text("iPhone connected - waiting for config...")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
    }
}

// MARK: - Mode Picker

struct ModePickerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Play Mode")
                    .font(.headline)
                    .padding(.top, 8)

                Text("iPhone is nearby. How should JUSPlay work?")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    appState.selectMode(.standalone)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "applewatch")
                            .font(.title2)
                        Text("Standalone")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Stream directly on Watch")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    appState.selectMode(.remote)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "iphone")
                            .font(.title2)
                        Text("Remote")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Control iPhone playback")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }
}
