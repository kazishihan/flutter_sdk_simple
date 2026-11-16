import UIKit

final class HostViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let messageField = UITextField()
    private let logView = UITextView()

    /// Builds the host dashboard UI and hooks up Flutter event logging.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        configureFieldsAndLog()
        setupLayout()

        FlutterHost.shared.onEvent = { [weak self] name, payload in
            self?.log("Event: \(name) \(payload)")
        }
    }

    /// Styles the text fields and monospace activity log view.
    private func configureFieldsAndLog() {
        messageField.borderStyle = .roundedRect
        messageField.text = "Hello from iOS"
        messageField.placeholder = "Message to send to Flutter"
        messageField.clearButtonMode = .whileEditing
        messageField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logView.backgroundColor = .tertiarySystemGroupedBackground
        logView.layer.cornerRadius = 10
        logView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        logView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
    }

    /// Arranges the header and grouped action cards inside a scrollable stack.
    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        // Header
        let titleLabel = UILabel()
        titleLabel.text = "Flutter SDK Host"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Manage the Flutter engine and bridge messages."
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        contentStack.addArrangedSubview(headerStack)
        contentStack.setCustomSpacing(16, after: headerStack)

        // Card 1: Flutter Engine
        let engineButtonsRow = UIStackView(arrangedSubviews: [
            makeButton("Start engine", style: .filled(), action: #selector(startTapped)),
            makeButton("Open Flutter", style: .tinted(), action: #selector(openTapped)),
        ])
        engineButtonsRow.axis = .horizontal
        engineButtonsRow.spacing = 10
        engineButtonsRow.distribution = .fillEqually

        let stopButton = makeButton("Stop engine", style: .bordered(), action: #selector(stopTapped))
        contentStack.addArrangedSubview(makeCard(title: "Flutter Engine", views: [engineButtonsRow, stopButton]))

        // Card 2: Bridge Messaging
        let sendButton = makeButton("Send data to Flutter", style: .tinted(), action: #selector(sendTapped))
        contentStack.addArrangedSubview(makeCard(title: "Send Message to Flutter", views: [messageField, sendButton]))

        // Card 3: Activity Log
        let logTitle = UILabel()
        logTitle.text = "Activity Log"
        logTitle.font = .preferredFont(forTextStyle: .subheadline)
        logTitle.textColor = .secondaryLabel

        var clearConfig = UIButton.Configuration.plain()
        clearConfig.title = "Clear"
        clearConfig.contentInsets = .zero
        let clearButton = UIButton(configuration: clearConfig)
        clearButton.addTarget(self, action: #selector(clearLogTapped), for: .touchUpInside)

        let logHeader = UIStackView(arrangedSubviews: [logTitle, UIView(), clearButton])
        logHeader.axis = .horizontal
        logHeader.alignment = .center

        contentStack.addArrangedSubview(makeCard(title: nil, views: [logHeader, logView]))
    }

    /// Wraps a section title and child views inside a rounded grouped card.
    private func makeCard(title: String?, views: [UIView]) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let title {
            let label = UILabel()
            label.text = title
            label.font = .preferredFont(forTextStyle: .headline)
            stack.addArrangedSubview(label)
        }
        views.forEach { stack.addArrangedSubview($0) }

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    /// Creates a consistently padded UIButton using the given configuration style.
    private func makeButton(
        _ title: String,
        style: UIButton.Configuration,
        action: Selector
    ) -> UIButton {
        var config = style
        config.title = title
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    /// Starts the cached Flutter engine with demo user config.
    @objc private func startTapped() {
        FlutterHost.shared.start(userId: "12345", language: Locale.current.languageCode ?? "en")
        log("Flutter engine started")
    }

    /// Presents the Flutter UI if the engine has been started.
    @objc private func openTapped() {
        guard FlutterHost.shared.isStarted else { return log("Start the engine first") }
        FlutterHost.shared.open(from: self)
    }

    /// Sends the message text field value to Flutter over the bridge channel.
    @objc private func sendTapped() {
        let text = messageField.text ?? ""
        FlutterHost.shared.sendData(text)
        log("Sent: \(text)")
    }

    /// Destroys the running Flutter engine and clears channel state.
    @objc private func stopTapped() {
        FlutterHost.shared.stop()
        log("Flutter engine stopped")
    }

    /// Clears all lines from the activity log view.
    @objc private func clearLogTapped() {
        logView.text = ""
    }

    /// Appends a log line and scrolls the activity log to the bottom.
    private func log(_ line: String) {
        logView.text += line + "\n"
        let bottom = NSRange(location: max(logView.text.count - 1, 0), length: 0)
        logView.scrollRangeToVisible(bottom)
    }
}
