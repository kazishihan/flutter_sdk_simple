import Flutter
import UIKit

/// Everything the app needs from Flutter, in one place: an engine, the
/// channel to the Flutter screen, and a way to open it.
final class FlutterHost {

    static let shared = FlutterHost()

    private let channelName = "com.example.flutter_module/bridge"
    private var engine: FlutterEngine?
    private var channel: FlutterMethodChannel?
    private weak var activeFlutterViewController: FlutterViewController?
    private var pendingPaymentResult: FlutterResult?

    /// Called when the Flutter screen sends an event. Set by the UI.
    var onEvent: ((String, [String: Any]) -> Void)?

    var isStarted: Bool { engine != nil }

    /// Starts the Flutter engine once and registers the bridge MethodChannel.
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
            case "openPayment":
                self?.handleOpenPayment(call.arguments, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        self.engine = engine
        self.channel = channel
    }

    /// Validates the phone argument and presents PaymentViewController over FlutterViewController.
    private func handleOpenPayment(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let rawPhone = args["phoneNumber"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Valid phone number is required", details: nil))
            return
        }
        let phone = rawPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PaymentViewController.isValidPhoneNumber(phone) else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Valid phone number is required", details: nil))
            return
        }
        guard pendingPaymentResult == nil else {
            result(FlutterError(code: "PAYMENT_IN_PROGRESS", message: "A payment is already in progress", details: nil))
            return
        }
        guard let presenter = activeFlutterViewController,
              presenter.presentedViewController == nil else {
            result(FlutterError(code: "NO_ACTIVE_HOST", message: "Flutter screen is not active", details: nil))
            return
        }

        pendingPaymentResult = result
        let paymentVC = PaymentViewController(phoneNumber: phone) { [weak self] outcome in
            guard let self else { return }
            let pending = self.pendingPaymentResult
            self.pendingPaymentResult = nil

            switch outcome {
            case .success(let confirmedPhone):
                pending?(["status": "success", "phoneNumber": confirmedPhone])
            case .failed(let confirmedPhone):
                pending?(["status": "failed", "phoneNumber": confirmedPhone])
            case .cancelled:
                pending?(["status": "cancelled", "phoneNumber": ""])
            }
        }
        let nav = UINavigationController(rootViewController: paymentVC)
        nav.modalPresentationStyle = .formSheet
        // Prevent swipe-down dismissal from bypassing the Cancel completion handler.
        nav.isModalInPresentation = true
        presenter.present(nav, animated: true)
    }

    /// Presents the stock FlutterViewController full-screen on top of the given presenter.
    func open(from presenter: UIViewController) {
        guard let engine else { return }
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        controller.modalPresentationStyle = .fullScreen
        activeFlutterViewController = controller
        presenter.present(controller, animated: true)
    }

    /// Sends a string message from the native host to Flutter.
    func sendData(_ text: String) {
        channel?.invokeMethod("receiveData", arguments: text)
    }

    /// Cancels any pending payment callback and destroys the Flutter engine.
    func stop() {
        let pending = pendingPaymentResult
        pendingPaymentResult = nil
        pending?(["status": "cancelled", "phoneNumber": ""])
        activeFlutterViewController = nil
        channel?.setMethodCallHandler(nil)
        engine?.destroyContext()
        channel = nil
        engine = nil
    }
}
