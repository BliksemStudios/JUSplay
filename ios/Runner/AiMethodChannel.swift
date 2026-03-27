import Flutter
import Foundation
import FoundationModels

/// On-device AI playlist generation via Apple Foundation Models (iOS 26+).
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
        guard call.method == "generatePlaylist" else {
            result(FlutterMethodNotImplemented)
            return
        }

        let args = call.arguments as? [String: Any]
        let prompt = args?["prompt"] as? String ?? ""
        let songList = args?["songList"] as? String ?? ""

        if #available(iOS 26.0, *) {
            Task {
                await self.generateOnDevice(prompt: prompt, songList: songList, result: result)
            }
        } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Requires iOS 26+", details: nil))
        }
    }

    @available(iOS 26.0, *)
    private func generateOnDevice(
        prompt: String,
        songList: String,
        result: @escaping FlutterResult
    ) async {
        // Check model availability before attempting generation
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            result(FlutterError(
                code: "UNAVAILABLE",
                message: "Apple Intelligence unavailable: \(reason)",
                details: nil
            ))
            return
        @unknown default:
            result(FlutterError(code: "UNAVAILABLE", message: "Apple Intelligence status unknown", details: nil))
            return
        }

        do {
            let session = LanguageModelSession()
            let fullPrompt = """
            You are a music curator. From the song list below, select up to 25 song IDs \
            that best match the user's request. Return ONLY a valid JSON array of song ID \
            strings. No other text.

            Songs (id|title|artist|genre|duration_secs):
            \(songList.isEmpty ? "(library unavailable)" : songList)

            User request: "\(prompt)"

            Response:
            """
            let response = try await session.respond(to: fullPrompt)
            result(response.content)
        } catch {
            result(FlutterError(
                code: "GENERATION_FAILED",
                message: "Foundation Models error: \(error.localizedDescription)",
                details: "\(error)"
            ))
        }
    }
}
