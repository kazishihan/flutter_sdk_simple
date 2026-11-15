import Flutter
import UIKit

/// Everything the app needs from Flutter, in one place: an engine, the
/// channel to the Flutter screen, and a way to open it.
final class FlutterHost {

    static let shared = FlutterHost()

    private let channelName = "com.example.flutter_module/bridge"
    private var engine: FlutterEngine?
    private var channel: FlutterMethodChannel?

    /// Called when the Flutter screen sends an event. Set by the UI.
    var onEvent: ((String, [String: Any]) -> Void)?

    var isStarted: Bool { engine != nil }

    /// Starts the Flutter engine once. Call it early (app launch or after login).
    /// Must be called on the main thread.
    func start(userId: String, language: String) {
        guard engine == nil else { return }
        let engine = FlutterEngine(name: "main_engine")

        // iOS requires the engine to be running before a handler can be set
        // (otherwise: "Setting a message handler before the FlutterEngine has
        // been run"). Nothing is missed: start() runs on the main thread, and
        // Dart's first message is delivered on that same thread, so the handler
        // below is in place before the run loop can deliver it.
        engine.run()

        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: engine.binaryMessenger)
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getConfig":
                result(["userId": userId, "language": language])
            case "sendEvent":
                guard let args = call.arguments as? [String: Any],
                      let name = args["name"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "name is missing", details: nil))
                    return
                }
                self?.onEvent?(name, args["payload"] as? [String: Any] ?? [:])
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        self.engine = engine
        self.channel = channel
    }

    /// Shows the Flutter screen full-screen. Needs `start` first.
    func open(from presenter: UIViewController) {
        guard let engine else { return }
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        controller.modalPresentationStyle = .fullScreen
        presenter.present(controller, animated: true)
    }

    /// Sends text to the Flutter screen.
    func sendData(_ text: String) {
        channel?.invokeMethod("receiveData", arguments: text)
    }

    /// Frees the engine (for example on logout). Close the Flutter screen first.
    func stop() {
        channel?.setMethodCallHandler(nil)
        engine?.destroyContext()
        channel = nil
        engine = nil
    }
}
