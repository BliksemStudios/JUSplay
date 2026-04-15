import Flutter
import WatchConnectivity

/// Bridges WatchConnectivity messages between the Apple Watch companion app
/// and the Flutter method channel for watch-related operations.
///
/// Sits on the iPhone side. Mirrors how CarPlaySceneDelegate bridges CarPlay.
@available(iOS 14.0, *)
class WatchSessionManager: NSObject, WCSessionDelegate, FlutterStreamHandler {

    static let shared = WatchSessionManager()

    private var watchChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?
    private var session: WCSession?

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// Call from AppDelegate once the binary messenger is available.
    func configure(messenger: FlutterBinaryMessenger) {
        watchChannel = FlutterMethodChannel(
            name: "com.bliksemstudios.jusplay/watch",
            binaryMessenger: messenger
        )

        let eventChannel = FlutterEventChannel(
            name: "com.bliksemstudios.jusplay/watch_events",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(self)

        // Listen for Dart → native → Watch pushes
        watchChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "playbackStateChanged":
                self?.sendPlaybackStateToWatch(call.arguments)
                result(nil)
            case "syncServerConfig":
                self?.sendServerConfigToWatch(call.arguments)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("[Watch] WCSession activated")
        }
    }

    // MARK: - Send to Watch

    /// Pushes playback state to the Watch app via WCSession application context.
    private func sendPlaybackStateToWatch(_ state: Any?) {
        guard let session = session,
              session.isPaired,
              session.isWatchAppInstalled else { return }

        var context: [String: Any] = ["type": "playbackState"]
        if let stateDict = state as? [String: Any] {
            context.merge(stateDict) { _, new in new }
        } else {
            context["stopped"] = true
        }

        do {
            try session.updateApplicationContext(context)
        } catch {
            print("[Watch] Failed to update application context: \(error)")
        }

        // Also send as a message for immediate delivery if reachable
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil) { error in
                print("[Watch] sendMessage error: \(error)")
            }
        }
    }

    /// Pushes server configuration to the Watch via both transferUserInfo
    /// (reliable, queued) and applicationContext (persistent, received on wake).
    private func sendServerConfigToWatch(_ config: Any?) {
        guard let session = session,
              session.isPaired,
              session.isWatchAppInstalled,
              let configDict = config as? [String: Any] else { return }

        var payload: [String: Any] = ["type": "serverConfig"]
        payload.merge(configDict) { _, new in new }

        // Queued reliable delivery
        session.transferUserInfo(payload)

        // Also persist as application context for late-wake scenarios
        // (merge with existing playback context)
        var context = (try? session.applicationContext) ?? [:]
        // Store server config separately so it doesn't overwrite playback state
        context["serverConfig"] = configDict
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("[Watch] Failed to update app context with server config: \(error)")
        }

        print("[Watch] Server config sent to Watch")
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        print("[Watch] Session activation: \(activationState.rawValue), error: \(String(describing: error))")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[Watch] Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[Watch] Session deactivated, reactivating...")
        session.activate()
    }

    /// Receives messages from the Watch app and forwards them to the Dart side.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard let method = message["method"] as? String else {
            replyHandler(["error": "No method specified"])
            return
        }

        var args: Any? = nil
        if let arguments = message["arguments"] as? [String: Any] {
            args = arguments
        }

        DispatchQueue.main.async { [weak self] in
            self?.watchChannel?.invokeMethod(method, arguments: args) { result in
                if let error = result as? FlutterError {
                    replyHandler(["error": error.message ?? "Unknown error"])
                } else if let data = result as? [String: Any] {
                    replyHandler(data)
                } else if let list = result as? [[String: Any]] {
                    replyHandler(["items": list])
                } else if result == nil {
                    replyHandler(["success": true])
                } else {
                    replyHandler(["result": "\(result ?? "nil")"])
                }
            }
        }
    }

    /// Receives messages without reply handler.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let method = message["method"] as? String else { return }

        var args: Any? = nil
        if let arguments = message["arguments"] as? [String: Any] {
            args = arguments
        }

        DispatchQueue.main.async { [weak self] in
            self?.watchChannel?.invokeMethod(method, arguments: args, result: nil)
        }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
