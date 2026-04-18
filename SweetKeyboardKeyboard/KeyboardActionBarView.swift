import UIKit

final class KeyboardActionBarView: UIView {
    enum Action {
        case copy
        case paste
        case clipboard
        case settings
    }

    var onAction: ((Action) -> Void)?

    private let copyButton = KeyboardActionBarView.makeTextButton(title: "Copy")
    private let pasteButton = KeyboardActionBarView.makeTextButton(title: "Paste")
    private let clipboardButton = KeyboardActionBarView.makeTextButton(title: "Clipboard")
    private let settingsButton = KeyboardActionBarView.makeIconButton(symbolName: "gearshape")

    private var isClipboardActive = false
    private var isSettingsActive = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        observeTraitChanges()
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setClipboardActive(_ active: Bool) {
        isClipboardActive = active
        applyTheme()
    }

    func setSettingsActive(_ active: Bool) {
        isSettingsActive = active
        applyTheme()
    }

    private func observeTraitChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) {
            (self: Self, _: UITraitCollection) in
            self.applyTheme()
        }
    }

    private func setup() {
        backgroundColor = .clear

        let leftStack = UIStackView(arrangedSubviews: [copyButton, pasteButton, clipboardButton])
        leftStack.axis = .horizontal
        leftStack.alignment = .fill
        leftStack.spacing = KeyboardMetrics.utilityRowButtonSpacing

        let rightStack = UIStackView(arrangedSubviews: [settingsButton])
        rightStack.axis = .horizontal
        rightStack.alignment = .fill
        rightStack.spacing = KeyboardMetrics.utilityGroupSpacing

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [leftStack, spacer, rightStack])
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = KeyboardMetrics.utilityGroupSpacing

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: KeyboardMetrics.utilityRowHeight)
        ])

        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        clipboardButton.addTarget(self, action: #selector(clipboardTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

        settingsButton.accessibilityLabel = "Settings"
        settingsButton.accessibilityHint = "Shows SweetKeyboard settings."
    }

    private func applyTheme() {
        KeyboardTheme.applyChrome(
            to: copyButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.utilityCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: pasteButton,
            role: .utility,
            cornerRadius: KeyboardMetrics.utilityCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: clipboardButton,
            role: .utility,
            isActive: isClipboardActive,
            cornerRadius: KeyboardMetrics.utilityCornerRadius
        )
        KeyboardTheme.applyChrome(
            to: settingsButton,
            role: .utility,
            isActive: isSettingsActive,
            cornerRadius: KeyboardMetrics.utilityCornerRadius
        )
    }

    private static func makeTextButton(title: String) -> UIButton {
        let button = KeyboardPressableButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleFonts(
            normal: UIFont.systemFont(ofSize: KeyboardMetrics.utilityButtonFontSize, weight: .regular),
            highlighted: UIFont.systemFont(ofSize: KeyboardMetrics.utilityButtonFontSize, weight: .semibold)
        )
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        if #available(iOS 15.0, *) {
            var configuration = button.configuration ?? .plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: KeyboardMetrics.utilityButtonHorizontalPadding,
                bottom: 0,
                trailing: KeyboardMetrics.utilityButtonHorizontalPadding
            )
            button.configuration = configuration
        } else {
            button.contentEdgeInsets = UIEdgeInsets(
                top: 0,
                left: KeyboardMetrics.utilityButtonHorizontalPadding,
                bottom: 0,
                right: KeyboardMetrics.utilityButtonHorizontalPadding
            )
        }
        button.heightAnchor.constraint(equalToConstant: KeyboardMetrics.utilityRowHeight).isActive = true
        return button
    }

    private static func makeIconButton(symbolName: String) -> UIButton {
        let button = KeyboardPressableButton(type: .custom)
        button.setSymbolConfigurations(
            normal: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .medium),
            highlighted: UIImage.SymbolConfiguration(pointSize: KeyboardMetrics.iconPointSize, weight: .semibold)
        )
        button.setImage(UIImage(systemName: symbolName), for: .normal)
        button.widthAnchor.constraint(equalToConstant: KeyboardMetrics.iconButtonWidth).isActive = true
        button.heightAnchor.constraint(equalToConstant: KeyboardMetrics.utilityRowHeight).isActive = true
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
