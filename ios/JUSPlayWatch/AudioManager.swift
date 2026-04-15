import AVFoundation
import MediaPlayer

/// Manages audio playback on the Watch using AVPlayer for streaming.
class AudioManager: ObservableObject {

    @Published var currentSong: SongItem?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    private(set) var queue: [SongItem] = []
    private(set) var currentIndex: Int = -1

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var didEndObserver: NSObjectProtocol?

    private var streamUrlProvider: ((String) -> String)?

    init() {
        configureAudioSession()
        setupRemoteCommands()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            print("[AudioManager] Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Playback

    func playQueue(songs: [SongItem], startIndex: Int = 0,
                   streamUrlProvider: @escaping (String) -> String) {
        self.queue = songs
        self.streamUrlProvider = streamUrlProvider
        playSongAt(startIndex)
    }

    func playSongAt(_ index: Int) {
        guard index >= 0, index < queue.count,
              let urlProvider = streamUrlProvider else { return }

        currentIndex = index
        let song = queue[index]
        let urlString = urlProvider(song.id)

        guard let url = URL(string: urlString) else { return }

        // Clean up previous player
        cleanupPlayer()

        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 30

        player = AVPlayer(playerItem: playerItem)

        // Observe status
        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    self?.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                }
            }
        }

        // Observe end of track
        didEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.skipNext()
        }

        // Periodic time updates
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds.isNaN ? 0 : time.seconds
            self?.updateNowPlayingTime()
        }

        currentSong = song
        isPlaying = true
        player?.play()
        updateNowPlayingInfo()
    }

    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func skipNext() {
        guard currentIndex < queue.count - 1 else { return }
        playSongAt(currentIndex + 1)
    }

    func skipPrevious() {
        // If more than 3 seconds in, restart current track
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard currentIndex > 0 else { return }
        playSongAt(currentIndex - 1)
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
        currentTime = seconds
        updateNowPlayingTime()
    }

    func stop() {
        cleanupPlayer()
        currentSong = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentIndex = -1
        queue = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func cleanupPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        if let observer = didEndObserver {
            NotificationCenter.default.removeObserver(observer)
            didEndObserver = nil
        }
        player?.pause()
        player = nil
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: Double(song.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        // Load artwork asynchronously
        if let urlString = song.coverArtUrl, let url = URL(string: urlString) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingTime() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipNext()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipPrevious()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
}
