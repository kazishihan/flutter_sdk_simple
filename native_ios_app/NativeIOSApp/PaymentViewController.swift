import UIKit

enum DemoPaymentResult {
    case success(phoneNumber: String)
    case failed(phoneNumber: String)
    case cancelled
}

final class PaymentViewController: UIViewController {

    private let phoneNumber: String
    private let onResult: (DemoPaymentResult) -> Void
    private var hasCompleted = false

    private let phoneField = UITextField()
    private let errorLabel = UILabel()

    /// Checks that the phone string has 6-20 allowed phone characters.
    static func isValidPhoneNumber(_ phone: String) -> Bool {
        guard !phone.isEmpty, phone.count <= 20 else { return false }
        let pattern = #"^\+?[0-9\s\-()]{6,20}$"#
        return phone.range(of: pattern, options: .regularExpression) != nil
    }

    /// Initializes the payment screen with a required phone number and result callback.
    init(phoneNumber: String, onResult: @escaping (DemoPaymentResult) -> Void) {
        self.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sets up the card UI, pre-fills the validated phone number, and adds navigation actions.
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Demo Payment"
        view.backgroundColor = .systemGroupedBackground

        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Confirm or fail the demo payment for the phone number below."
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        phoneField.borderStyle = .roundedRect
        phoneField.placeholder = "Phone number"
        phoneField.keyboardType = .phonePad
        phoneField.clearButtonMode = .whileEditing
        phoneField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        if Self.isValidPhoneNumber(phoneNumber) {
            phoneField.text = phoneNumber
        }

        errorLabel.textColor = .systemRed
        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let successButton = makeActionButton(
            title: "Success",
            backgroundColor: .systemGreen,
            action: #selector(successTapped)
        )
        let failedButton = makeActionButton(
            title: "Failed",
            backgroundColor: .systemRed,
            action: #selector(failedTapped)
        )

        let buttonRow = UIStackView(arrangedSubviews: [successButton, failedButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually

        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [subtitleLabel, phoneField, errorLabel, buttonRow])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            card.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
    }

    /// Creates a filled colored button for payment success/failed actions.
    private func makeActionButton(
        title: String,
        backgroundColor: UIColor,
        action: Selector
    ) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = backgroundColor
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    /// Completes the demo payment with a success outcome.
    @objc private func successTapped() {
        finishWithOutcome { .success(phoneNumber: $0) }
    }

    /// Completes the demo payment with a failed outcome.
    @objc private func failedTapped() {
        finishWithOutcome { .failed(phoneNumber: $0) }
    }

    /// Dismisses the payment screen and reports cancellation.
    @objc private func cancelTapped() {
        completeOnce(.cancelled)
    }

    /// Validates the entered phone number before delivering a success/failed outcome.
    private func finishWithOutcome(_ makeResult: (String) -> DemoPaymentResult) {
        let phone = (phoneField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidPhoneNumber(phone) else {
            errorLabel.text = "Enter a valid phone number (6-20 digits)"
            errorLabel.isHidden = false
            phoneField.becomeFirstResponder()
            return
        }
        errorLabel.isHidden = true
        completeOnce(makeResult(phone))
    }

    /// Ensures the completion callback runs once and clears sensitive input before dismissing.
    private func completeOnce(_ result: DemoPaymentResult) {
        guard !hasCompleted else { return }
        hasCompleted = true
        phoneField.text = nil
        dismiss(animated: true) { [onResult] in
            onResult(result)
        }
    }
}
