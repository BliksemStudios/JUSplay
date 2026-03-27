import Flutter
import Foundation

/// Stub for Apple Foundation Models AI integration.
///
/// Currently returns `FlutterMethodNotImplemented` for all calls so that
/// the Flutter side falls through to Gemini. Replace this implementation
/// with actual FoundationModels calls when targeting iOS 18.1+.
@objc class AiMethodChannel: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.bliksemstudios.jusplay/ai",
            binaryMessenger: registrar.messenger()
        )
        let instance = AiMethodChannel()
        channel.setMethodCallHandler(instance.handle(_:result:))
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Stub: return not-implemented so Flutter falls back to Gemini
        result(FlutterMethodNotImplemented)
    }
}
