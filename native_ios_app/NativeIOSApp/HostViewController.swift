import UIKit

final class HostViewController: UIViewController {

    private let messageField = UITextField()
    private let logView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        messageField.borderStyle = .roundedRect
        messageField.text = "Hello from iOS"
        messageField.placeholder = "Message to send to Flutter"

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        logView.backgroundColor = .secondarySystemBackground

        let stack = UIStackView(arrangedSubviews: [
            makeButton("Start Flutter engine", #selector(startTapped)),
            makeButton("Open Flutter screen", #selector(openTapped)),
            messageField,
            makeButton("Send data to Flutter", #selector(sendTapped)),
            makeButton("Stop engine", #selector(stopTapped)),
            logView,
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])

        FlutterHost.shared.onEvent = { [weak self] name, payload in
            self?.log("Event: \(name) \(payload)")
        }
    }

    private func makeButton(_ title: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func startTapped() {
        FlutterHost.shared.start(userId: "12345", language: Locale.current.languageCode ?? "en")
        log("Flutter engine started")
    }

    @objc private func openTapped() {
        guard FlutterHost.shared.isStarted else { return log("Start the engine first") }
        FlutterHost.shared.open(from: self)
    }

    @objc private func sendTapped() {
        let text = messageField.text ?? ""
        FlutterHost.shared.sendData(text)
        log("Sent: \(text)")
    }

    @objc private func stopTapped() {
        FlutterHost.shared.stop()
        log("Flutter engine stopped")
    }

    private func log(_ line: String) {
        logView.text += line + "\n"
    }
}
