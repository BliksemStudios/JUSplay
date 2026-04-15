import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The binary messenger from the Flutter engine, exposed for CarPlay & Watch.
  private(set) var binaryMessenger: FlutterBinaryMessenger?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Capture the binary messenger for CarPlay method channel
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CarPlayBridge") {
      binaryMessenger = registrar.messenger()
    }

    // Register AI method channel
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AiMethodChannel") {
      AiMethodChannel.register(with: registrar)
    }

    // Configure WatchConnectivity bridge
    if let messenger = binaryMessenger {
      if #available(iOS 14.0, *) {
        WatchSessionManager.shared.configure(messenger: messenger)
      }
    }
  }
}
