import UIKit

final class KeyboardActionBarView: UIView {
    enum Action {
        case copy
        case paste
        case clipboard
        case settings
    }

    var onAction: ((Action) -> Void)?

    private let copyButton = KeyboardActionBarView.makeButton(title: "Copy")
    private let pasteButton = KeyboardActionBarView.makeButton(title: "Paste")
    private let clipboardButton = KeyboardActionBarView.makeButton(title: "Clipboard")
    private let settingsButton = KeyboardActionBarView.makeButton(title: "Settings")

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setClipboardActive(_ active: Bool) {
        clipboardButton.backgroundColor = active ? .systemGray3 : .secondarySystemFill
    }

    func setSettingsActive(_ active: Bool) {
        settingsButton.backgroundColor = active ? .systemGray3 : .secondarySystemFill
    }

    private func setup() {
        let stack = UIStackView(arrangedSubviews: [copyButton, pasteButton, clipboardButton, settingsButton])
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 8

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 40)
        ])

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        clipboardButton.addTarget(self, action: #selector(clipboardTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
    }

    private static func makeButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.backgroundColor = .secondarySystemFill
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
        return button
    }

    @objc private func copyTapped() {
        onAction?(.copy)
    }

    @objc private func pasteTapped() {
        onAction?(.paste)
    }

    @objc private func clipboardTapped() {
        onAction?(.clipboard)
    }

    @objc private func settingsTapped() {
        onAction?(.settings)
    }
}
